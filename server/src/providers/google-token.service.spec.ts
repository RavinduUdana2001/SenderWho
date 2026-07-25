import { BadGatewayException, UnauthorizedException } from "@nestjs/common";
import { GoogleTokenService } from "./google-token.service";

describe("GoogleTokenService", () => {
  const originalFetch = global.fetch;

  afterEach(() => {
    global.fetch = originalFetch;
    jest.restoreAllMocks();
  });

  function setup(providerError: string) {
    const config = {
      get: jest.fn((key: string) => {
        if (key === "oauth.google.clientId") return "google-client";
        if (key === "oauth.google.clientSecret") return "google-secret";
        return undefined;
      }),
    };
    const prisma = {
      emailAccount: {
        findUnique: jest.fn().mockResolvedValue({
          provider: "GOOGLE",
          providerAccountId: "google-subject-1",
          syncStatus: "FAILED",
          accessTokenEncrypted: "encrypted-access",
          refreshTokenEncrypted: "encrypted-refresh",
          tokenExpiresAt: new Date(0),
        }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    const encryption = {
      decrypt: jest.fn().mockReturnValue("refresh-token"),
      encrypt: jest.fn((value: string) => `encrypted:${value}`),
    };
    global.fetch = jest.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          error: providerError,
          error_description: "Provider explanation",
        }),
        {
          status: 401,
          headers: { "content-type": "application/json" },
        },
      ),
    );
    return {
      service: new GoogleTokenService(
        config as never,
        prisma as never,
        encryption as never,
      ),
      prisma,
    };
  }

  it("turns a revoked refresh token into a reconnect-required account", async () => {
    const { service, prisma } = setup("invalid_grant");

    await expect(service.getAccessToken("account-1")).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(prisma.emailAccount.update).toHaveBeenCalledWith({
      where: { id: "account-1" },
      data: {
        syncStatus: "DISCONNECTED",
        lastSyncError:
          "Google access expired or was revoked. Reconnect Gmail to continue scanning.",
      },
    });
  });

  it("reports a disabled OAuth client with an actionable configuration error", async () => {
    const { service } = setup("disabled_client");

    await expect(service.getAccessToken("account-1")).rejects.toMatchObject({
      constructor: BadGatewayException,
      message:
        "The SenderWho Google OAuth client is disabled. Enable it in Google Cloud Console, then reconnect Gmail.",
    });
  });
});
