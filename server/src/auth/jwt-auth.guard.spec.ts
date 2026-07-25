import { ExecutionContext } from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { JwtService } from "@nestjs/jwt";
import { PrismaService } from "../database/prisma.service";
import { IS_PUBLIC_KEY } from "./public.decorator";
import { RECENT_AUTH_MAX_AGE_SECONDS_KEY } from "./require-recent-auth.decorator";
import { JwtAuthGuard } from "./jwt-auth.guard";

describe("JwtAuthGuard", () => {
  function setup(options: { activeSession: boolean; recentAge?: number }) {
    const request = {
      headers: { authorization: "Bearer access-token" },
    };
    const context = {
      getHandler: jest.fn(),
      getClass: jest.fn(),
      switchToHttp: () => ({ getRequest: () => request }),
    } as unknown as ExecutionContext;
    const reflector = {
      getAllAndOverride: jest.fn((metadataKey: string) => {
        if (metadataKey === IS_PUBLIC_KEY) return false;
        if (metadataKey === RECENT_AUTH_MAX_AGE_SECONDS_KEY) {
          return options.recentAge;
        }
        return undefined;
      }),
    } as unknown as Reflector;
    const jwt = {
      verifyAsync: jest.fn().mockResolvedValue({
        sub: "user-1",
        email: "person@example.com",
        type: "access",
        sid: "session-1",
        auth_time: Math.floor(Date.now() / 1_000) - 700,
      }),
    } as unknown as JwtService;
    const prisma = {
      mockDataEnabled: false,
      appSession: {
        findFirst: jest
          .fn()
          .mockResolvedValue(
            options.activeSession ? { id: "session-1" } : null,
          ),
      },
    } as unknown as PrismaService;
    return {
      guard: new JwtAuthGuard(reflector, jwt, prisma),
      context,
      request,
    };
  }

  it("rejects a valid JWT after its backing session is revoked", async () => {
    const { guard, context } = setup({ activeSession: false });

    await expect(guard.canActivate(context)).rejects.toThrow("revoked");
  });

  it("requires a recent login for a step-up protected operation", async () => {
    const { guard, context } = setup({ activeSession: true, recentAge: 600 });

    await expect(guard.canActivate(context)).rejects.toThrow(
      "Recent authentication",
    );
  });
});
