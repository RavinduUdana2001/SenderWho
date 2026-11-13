import { Controller, Get, INestApplication, UseGuards } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Reflector } from "@nestjs/core";
import { JwtService } from "@nestjs/jwt";
import { Test } from "@nestjs/testing";
import { createCipheriv, randomBytes } from "node:crypto";
import { request } from "node:http";
import { AddressInfo } from "node:net";
import { JwtAuthGuard } from "../../auth/jwt-auth.guard";
import { PrismaService } from "../../database/prisma.service";
import { TokenEncryptionService } from "./token-encryption.service";

// Test-only routes. No cryptographic diagnostic endpoint is added to production.
describe("cryptographic failure HTTP responses", () => {
  let app: INestApplication;
  let operation: () => unknown;
  const secret = randomBytes(64);
  const jwt = new JwtService({ secret });
  const service = (auth: Record<string, string> = {}) =>
    new TokenEncryptionService(new ConfigService({ auth }));
  const key = randomBytes(32).toString("base64");
  const valid = service({ tokenEncryptionKey: key });
  const plaintext = "SYNTHETIC-PLAINTEXT-MUST-NOT-LEAK";
  const payload = valid.encrypt(plaintext);
  const mutate = (index: number, bytes?: Buffer) => {
    const parts = payload.split(".");
    const value = bytes ?? Buffer.from(parts[index], "base64url");
    if (!bytes) value[0] ^= 1;
    parts[index] = value.toString("base64url");
    return parts.join(".");
  };
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", Buffer.from(key, "base64"), iv);
  const encrypted = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const legacy = [
    "v1",
    iv.toString("base64url"),
    cipher.getAuthTag().toString("base64url"),
    encrypted.toString("base64url"),
  ].join(".");

  @Controller()
  class ProbeController {
    @Get("crypto")
    crypto() {
      return operation();
    }

    @Get("protected")
    @UseGuards(JwtAuthGuard)
    protected() {
      return { allowed: true };
    }
  }

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [ProbeController],
      providers: [
        Reflector,
        JwtAuthGuard,
        { provide: JwtService, useValue: jwt },
        { provide: PrismaService, useValue: { mockDataEnabled: true } },
      ],
    }).compile();
    app = module.createNestApplication({ logger: false });
    await app.listen(0, "127.0.0.1");
  });
  afterAll(async () => {
    await app?.close();
  });

  const send = (path: string, token?: string) =>
    new Promise<{ status: number; body: unknown }>((resolve, reject) => {
      const port = (app.getHttpServer().address() as AddressInfo).port;
      const req = request(
        {
          host: "127.0.0.1",
          port,
          path,
          headers: token ? { authorization: `Bearer ${token}` } : {},
        },
        (res) => {
          let body = "";
          res.setEncoding("utf8");
          res.on("data", (chunk: string) => {
            body += chunk;
          });
          res.on("end", () =>
            resolve({ status: res.statusCode!, body: JSON.parse(body) }),
          );
        },
      );
      req.on("error", reject);
      req.end();
    });

  it.each([
    ["malformed ciphertext", () => valid.decrypt("invalid")],
    ["unsupported version", () => valid.decrypt(payload.replace("v2.", "v9."))],
    ["extra payload segment", () => valid.decrypt(`${payload}.extra`)],
    ["corrupted ciphertext", () => valid.decrypt(mutate(4))],
    ["corrupted authentication tag", () => valid.decrypt(mutate(3))],
    [
      "invalid authentication tag length",
      () => valid.decrypt(mutate(3, randomBytes(3))),
    ],
    ["invalid IV length", () => valid.decrypt(mutate(2, Buffer.alloc(0)))],
    ["wrong record context", () => valid.decrypt(payload, "other-account")],
    [
      "unknown key identifier",
      () => valid.decrypt(payload.replace(".legacy.", ".INTERNAL-KEY-ID.")),
    ],
    ["missing decryption keys", () => service().decrypt(payload)],
    [
      "wrong decryption key",
      () =>
        service({
          tokenEncryptionKey: randomBytes(32).toString("base64"),
        }).decrypt(payload),
    ],
    ["missing encryption keys", () => service().encrypt(plaintext)],
    [
      "invalid encryption key size",
      () =>
        service({
          tokenEncryptionKey: randomBytes(16).toString("base64"),
        }).encrypt(plaintext),
    ],
    [
      "unavailable active key",
      () =>
        service({
          tokenEncryptionKey: key,
          tokenEncryptionActiveKeyId: "INTERNAL-KEY-ID",
        }).encrypt(plaintext),
    ],
    ["rotation configuration failure", () => service().needsRotation(payload)],
    ["legacy missing key", () => service().decrypt(legacy)],
    [
      "legacy invalid key size",
      () => service({ tokenEncryptionKey: "bad" }).decrypt(legacy),
    ],
    [
      "legacy corrupted ciphertext",
      () => valid.decrypt(`${legacy.slice(0, -2)}XX`),
    ],
    ["legacy extra segment", () => valid.decrypt(`${legacy}.extra`)],
  ])("%s returns the same safe 503 without plaintext", async (_name, run) => {
    operation = run as () => unknown;
    expect(await send("/crypto")).toEqual({
      status: 503,
      body: {
        statusCode: 503,
        message: "Secure credential processing failed.",
        error: "Service Unavailable",
      },
    });
  });

  it.each([
    ["malformed JWT", () => "invalid"],
    [
      "wrong JWT signature",
      () =>
        new JwtService({ secret: randomBytes(64) }).sign({ sub: "synthetic" }),
    ],
    ["expired JWT", () => jwt.sign({ sub: "synthetic" }, { expiresIn: -1 })],
    [
      "future JWT",
      () =>
        jwt.sign({
          sub: "synthetic",
          nbf: Math.floor(Date.now() / 1000) + 3600,
        }),
    ],
    [
      "unsigned JWT",
      () =>
        `${Buffer.from('{"alg":"none"}').toString("base64url")}.${Buffer.from('{"sub":"synthetic"}').toString("base64url")}.`,
    ],
    ["invalid JWT claims", () => jwt.sign({ sub: "synthetic" })],
  ])("%s is denied with a generic 401", async (_name, token) => {
    expect(await send("/protected", (token as () => string)())).toEqual({
      status: 401,
      body: {
        statusCode: 401,
        message: "The app session is invalid or expired.",
        error: "Unauthorized",
      },
    });
  });

  it("returns plaintext only after successful authentication for v1 and v2", () => {
    expect(valid.decrypt(payload)).toBe(plaintext);
    expect(valid.decrypt(legacy)).toBe(plaintext);
  });
});
