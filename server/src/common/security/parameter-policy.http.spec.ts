import {
  Body,
  Controller,
  INestApplication,
  Param,
  Post,
  ValidationPipe,
} from "@nestjs/common";
import { Test } from "@nestjs/testing";
import { IsArray, IsOptional, IsString, MaxLength } from "class-validator";
import { json, urlencoded } from "express";
import { request } from "node:http";
import { AddressInfo } from "node:net";
import {
  rejectDuplicateParameters,
  verifyFormParameters,
  verifyJsonParameters,
} from "./request-parameters";

class ActionDto {
  @IsOptional() @IsString() @MaxLength(40) id?: string;
  @IsOptional() @IsArray() @IsString({ each: true }) ids?: string[];
}

describe("parameter policy through Nest HTTP parsing and validation", () => {
  let app: INestApplication;
  let calls = 0;
  @Controller()
  class ProbeController {
    @Post("action/:id")
    action(@Param("id") routeId: string, @Body() body: ActionDto) {
      calls++;
      return { routeId, body };
    }
  }
  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [ProbeController],
    }).compile();
    app = module.createNestApplication({ bodyParser: false, logger: false });
    app.use(rejectDuplicateParameters);
    app.use(json({ strict: true, verify: verifyJsonParameters }));
    app.use(urlencoded({ extended: false, verify: verifyFormParameters }));
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.listen(0, "127.0.0.1");
  });
  afterAll(async () => {
    await app?.close();
  });
  const send = (query: string, body: string, type = "application/json") =>
    new Promise<{ status: number; body: Record<string, unknown> }>(
      (resolve, reject) => {
        const port = (app.getHttpServer().address() as AddressInfo).port;
        const req = request(
          {
            host: "127.0.0.1",
            port,
            method: "POST",
            path: `/action/route-value${query}`,
            headers: { "content-type": type },
          },
          (res) => {
            let value = "";
            res.setEncoding("utf8");
            res.on("data", (chunk: string) => {
              value += chunk;
            });
            res.on("end", () =>
              resolve({ status: res.statusCode!, body: JSON.parse(value) }),
            );
          },
        );
        req.on("error", reject);
        req.end(body);
      },
    );
  it.each([
    ["query conflicting values", "?id=a&id=b", "{}", "application/json"],
    ["query identical values", "?id=a&id=a", "{}", "application/json"],
    ["query percent-encoded alias", "?id=a&%69d=b", "{}", "application/json"],
    ["query bracket alias", "?id=a&id[]=b", "{}", "application/json"],
    [
      "query repeated bracket values",
      "?id[]=a&id[]=b",
      "{}",
      "application/json",
    ],
    [
      "form conflicting values",
      "",
      "id=a&id=b",
      "application/x-www-form-urlencoded",
    ],
    [
      "form identical values",
      "",
      "id=a&id=a",
      "application/x-www-form-urlencoded",
    ],
    [
      "form percent-encoded alias",
      "",
      "id=a&%69d=b",
      "application/x-www-form-urlencoded",
    ],
    [
      "form bracket alias",
      "",
      "id=a&id[]=b",
      "application/x-www-form-urlencoded",
    ],
    ["JSON conflicting keys", "", '{"id":"a","id":"b"}', "application/json"],
    ["JSON identical keys", "", '{"id":"a","id":"a"}', "application/json"],
    [
      "JSON escaped key alias",
      "",
      '{"id":"a","\\u0069d":"b"}',
      "application/json",
    ],
    [
      "nested JSON duplicate keys",
      "",
      '{"nested":{"id":"a","id":"b"}}',
      "application/json",
    ],
    [
      "duplicate keys inside JSON array",
      "",
      '{"ids":[{"id":"a","id":"b"}]}',
      "application/json",
    ],
  ])(
    "rejects %s before controller execution",
    async (_name, query, body, type) => {
      const before = calls;
      const response = await send(query, body, type);
      expect(response).toEqual({
        status: 400,
        body: {
          message: "Duplicate request parameters are not allowed.",
          error: "Bad Request",
          statusCode: 400,
        },
      });
      expect(calls).toBe(before);
    },
  );
  it("accepts explicit JSON arrays", async () => {
    expect(await send("", '{"ids":["a","b"]}')).toEqual({
      status: 201,
      body: { routeId: "route-value", body: { ids: ["a", "b"] } },
    });
  });
  it("accepts an unambiguous form body", async () => {
    expect(
      (await send("", "id=a", "application/x-www-form-urlencoded")).status,
    ).toBe(201);
  });
  it("accepts an empty JSON body for optional inputs", async () => {
    expect((await send("", "")).status).toBe(201);
  });
  it("keeps route, query and body sources separate without merging", async () => {
    expect(await send("?id=query-value", '{"id":"body-value"}')).toEqual({
      status: 201,
      body: { routeId: "route-value", body: { id: "body-value" } },
    });
  });
  it.each([
    ["unknown DTO field", '{"admin":true}'],
    ["invalid DTO type", '{"id":123}'],
    ["invalid DTO length", JSON.stringify({ id: "x".repeat(41) })],
  ])("rejects %s before controller execution", async (_name, body) => {
    const before = calls;
    expect((await send("", body)).status).toBe(400);
    expect(calls).toBe(before);
  });
});
