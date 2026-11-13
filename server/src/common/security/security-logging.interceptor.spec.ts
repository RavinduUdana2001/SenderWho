import {
  ExecutionContext,
  Logger,
  UnauthorizedException,
} from "@nestjs/common";
import { createHash } from "node:crypto";
import { lastValueFrom, of, throwError } from "rxjs";
import { SecurityLoggingInterceptor } from "./security-logging.interceptor";

describe("security log data minimization", () => {
  const secret = "SYNTHETIC_SECRET_DO_NOT_LOG_987654321";
  const sessionId = "test-session-secret-identifier";
  let log: jest.SpyInstance;
  let warn: jest.SpyInstance;
  let error: jest.SpyInstance;
  beforeEach(() => {
    log = jest
      .spyOn(Logger.prototype, "log")
      .mockImplementation(() => undefined);
    warn = jest
      .spyOn(Logger.prototype, "warn")
      .mockImplementation(() => undefined);
    error = jest
      .spyOn(Logger.prototype, "error")
      .mockImplementation(() => undefined);
  });
  afterEach(() => jest.restoreAllMocks());
  function fixture(route: string | undefined = "/auth/oauth/session/exchange") {
    const response = { statusCode: 201, setHeader: jest.fn() };
    const request = {
      method: "POST",
      path: "/" + secret,
      originalUrl: "/auth?code=" + secret,
      query: { code: secret, state: secret },
      body: { password: secret, refreshToken: secret, cardNumber: secret },
      headers: { authorization: "Bearer " + secret, "x-api-key": secret },
      user: { id: "test-user", sessionId },
      route: route ? { path: route } : undefined,
      header: (name: string) =>
        name === "x-senderwho-device-id" ? secret : secret,
    };
    const context = {
      switchToHttp: () => ({
        getRequest: () => request,
        getResponse: () => response,
      }),
    } as unknown as ExecutionContext;
    return { context, response };
  }
  it("omits request/response secrets and hashes session/device identifiers on success", async () => {
    const { context, response } = fixture();
    await lastValueFrom(
      new SecurityLoggingInterceptor().intercept(context, {
        handle: () => of({ accessToken: secret, refreshToken: secret }),
      }),
    );
    const record = JSON.parse(log.mock.calls[0][0]);
    expect(JSON.stringify(record)).not.toContain(secret);
    expect(JSON.stringify(record)).not.toContain(sessionId);
    expect(record.actorSessionHash).toBe(
      createHash("sha256").update(sessionId).digest("hex"),
    );
    expect(record.deviceHash).toMatch(/^[a-f0-9]{24}$/);
    expect(record.correlationId).toMatch(/^[a-f0-9-]{36}$/);
    expect(record.route).toBe("/auth/oauth/session/exchange");
    expect(response.setHeader).toHaveBeenCalledWith(
      "X-Request-Id",
      record.correlationId,
    );
  });
  it.each([new UnauthorizedException(secret), new Error(secret)])(
    "omits raw exception details on failure",
    async (failure) => {
      const { context } = fixture();
      await expect(
        lastValueFrom(
          new SecurityLoggingInterceptor().intercept(context, {
            handle: () => throwError(() => failure),
          }),
        ),
      ).rejects.toBe(failure);
      const calls = [...warn.mock.calls, ...error.mock.calls];
      expect(calls).toHaveLength(1);
      expect(calls[0][0]).not.toContain(secret);
      expect(calls[0][0]).not.toContain(sessionId);
      expect(JSON.parse(calls[0][0]).actorSessionHash).toMatch(
        /^[a-f0-9]{64}$/,
      );
    },
  );
  it("does not log an unmatched attacker-controlled path", async () => {
    const { context } = fixture(undefined);
    // Explicitly remove the route because fixture's default models a registered route.
    context.switchToHttp().getRequest().route = undefined;
    await lastValueFrom(
      new SecurityLoggingInterceptor().intercept(context, {
        handle: () => of({}),
      }),
    );
    expect(JSON.parse(log.mock.calls[0][0]).route).toBe("[unmatched]");
    expect(log.mock.calls[0][0]).not.toContain(secret);
  });
});
