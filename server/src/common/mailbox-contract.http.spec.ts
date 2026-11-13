import "reflect-metadata";
import { INestApplication, ValidationPipe } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import { SenderCategory } from "@prisma/client";
import { request } from "node:http";
import { AddressInfo } from "node:net";
import { SendersController } from "../senders/senders.controller";
import { SendersService } from "../senders/senders.service";
import { EmailMessagesController } from "../email-messages/email-messages.controller";
import { EmailMessagesService } from "../email-messages/email-messages.service";

// Exercise the real query DTOs over HTTP with production's strict validation.
// A mock that accepts arbitrary query keys cannot catch the screenshot failure.
describe("Flutter mailbox query contract over HTTP", () => {
  let app: INestApplication;
  const senders = { list: jest.fn() };
  const emails = { list: jest.fn() };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [SendersController, EmailMessagesController],
      providers: [
        { provide: SendersService, useValue: senders },
        { provide: EmailMessagesService, useValue: emails },
      ],
    }).compile();
    app = module.createNestApplication({ logger: false });
    app.setGlobalPrefix("api/v1");
    app.use((req: any, _res: any, next: () => void) => {
      req.user = { id: "owner" };
      next();
    });
    app.useGlobalPipes(
      new ValidationPipe({
        transform: true,
        whitelist: true,
        forbidNonWhitelisted: true,
      }),
    );
    await app.listen(0, "127.0.0.1");
  });

  beforeEach(() => {
    senders.list
      .mockReset()
      .mockResolvedValue({ items: [], total: 0, page: 1, limit: 25 });
    emails.list
      .mockReset()
      .mockResolvedValue({ items: [], total: 0, page: 1, limit: 25 });
  });

  afterAll(async () => {
    await app?.close();
  });

  const get = (path: string) =>
    new Promise<{ status: number; body: any }>((resolve, reject) => {
      const port = (app.getHttpServer().address() as AddressInfo).port;
      const req = request(
        { host: "127.0.0.1", port, path: `/api/v1/${path}` },
        (res) => {
          let body = "";
          res.setEncoding("utf8");
          res.on("data", (chunk) => {
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

  for (const endpoint of ["senders", "emails"] as const) {
    it.each(Object.values(SenderCategory))(
      `accepts ${endpoint} mailbox and %s filter without stripping either`,
      async (category) => {
        const query = new URLSearchParams({
          emailAccountId: "second-mailbox",
          category,
          query: "updates",
          page: "1",
          limit: "25",
          ...(endpoint === "senders"
            ? { kind: "ALL", control: "ALL" }
            : { mailbox: "INBOX" }),
        });
        const response = await get(`${endpoint}?${query}`);
        expect(response.status).toBe(200);
        expect(
          (endpoint === "senders" ? senders : emails).list,
        ).toHaveBeenCalledWith(
          "owner",
          expect.objectContaining({
            emailAccountId: "second-mailbox",
            category,
            query: "updates",
            page: 1,
            limit: 25,
          }),
        );
      },
    );

    it(`still rejects unexpected ${endpoint} parameters`, async () => {
      const response = await get(
        `${endpoint}?emailAccountId=second-mailbox&unrecognized=true`,
      );
      expect(response.status).toBe(400);
      expect(response.body.message).toContain(
        "property unrecognized should not exist",
      );
      expect(
        (endpoint === "senders" ? senders : emails).list,
      ).not.toHaveBeenCalled();
    });
  }
});
