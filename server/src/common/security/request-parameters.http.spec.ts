import express, { json, urlencoded } from "express";
import { request } from "node:http";
import { AddressInfo } from "node:net";
import {
  rejectDuplicateParameters,
  verifyJsonParameters,
  verifyFormParameters,
} from "./request-parameters";

it("rejects ambiguous requests before executing business logic", async () => {
  const app = express();
  let calls = 0;
  app.use(rejectDuplicateParameters);
  app.use(json({ verify: verifyJsonParameters }));
  app.use(urlencoded({ extended: false, verify: verifyFormParameters }));
  app.post("/action", (_req, res) => {
    calls++;
    res.json({ ok: true });
  });
  app.use(
    (
      error: { status?: number },
      _req: express.Request,
      res: express.Response,
      _next: express.NextFunction,
    ) => {
      res.status(error.status || 500).json({ message: "Request rejected" });
    },
  );
  const server = app.listen(0, "127.0.0.1");
  await new Promise<void>((resolve) => server.once("listening", resolve));
  const port = (server.address() as AddressInfo).port;
  const send = (path: string, body: string, type = "application/json") =>
    new Promise<number>((resolve, reject) => {
      const req = request(
        {
          host: "127.0.0.1",
          port,
          path,
          method: "POST",
          headers: { "content-type": type },
        },
        (res) => {
          res.resume();
          res.on("end", () => resolve(res.statusCode!));
        },
      );
      req.on("error", reject);
      req.end(body);
    });
  try {
    expect(await send("/action?id=a&id=b", "{}")).toBe(400);
    expect(await send("/action", '{"id":1,"id":2}')).toBe(400);
    expect(
      await send("/action", "id=1&id=2", "application/x-www-form-urlencoded"),
    ).toBe(400);
    expect(await send("/action", '{"ids":["a","b"]}')).toBe(200);
    expect(await send("/action", "")).toBe(200);
    expect(await send("/action", " ")).toBe(400);
    expect(await send("/action", '{"broken":')).toBe(400);
    expect(calls).toBe(2);
  } finally {
    await new Promise<void>((resolve, reject) =>
      server.close((e) => (e ? reject(e) : resolve())),
    );
  }
});
