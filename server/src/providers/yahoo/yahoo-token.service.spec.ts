import { UnauthorizedException } from "@nestjs/common";
import { YahooTokenService } from "./yahoo-token.service";

describe("YahooTokenService", () => {
  const originalFetch = global.fetch;

  afterEach(() => {
    global.fetch = originalFetch;
    jest.restoreAllMocks();
  });

  function setup(response: Response) {
    const config = {
      get: jest.fn((key: string) => {
        if (key === "oauth.yahoo.clientId") return "yahoo-client";
        if (key === "oauth.yahoo.clientSecret") return "yahoo-secret";
        if (key === "oauth.yahoo.callbackUrl") {
          return "https://api.example.test/auth/oauth/yahoo/callback";
        }
        return undefined;
      }),
    };
    const prisma = {
      emailAccount: {
        findUnique: jest.fn().mockResolvedValue({
          provider: "YAHOO",
          providerAccountId: "yahoo-subject-1",
          syncStatus: "READY",
          accessTokenEncrypted: "encrypted-expired-access",
          refreshTokenEncrypted: "encrypted-refresh",
          tokenExpiresAt: new Date(0),
        }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    const encryption = {
      decrypt: jest.fn().mockReturnValue("refresh-token"),
      encrypt: jest.fn((value: string) => `encrypted:${value}`),
      needsRotation: jest.fn().mockReturnValue(false),
    };
    global.fetch = jest.fn().mockResolvedValue(response);
    return {
      service: new YahooTokenService(
        config as never,
        prisma as never,
        encryption as never,
      ),
      prisma,
    };
  }

  it("refreshes and persists Yahoo OAuth access tokens", async () => {
    const { service, prisma } = setup(
      new Response(
        JSON.stringify({
          access_token: "new-access",
          refresh_token: "rotated-refresh",
          expires_in: 3600,
          scope: "openid email profile mail-r mail-w",
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      ),
    );

    await expect(service.getAccessToken("account-1")).resolves.toBe(
      "new-access",
    );
    expect(prisma.emailAccount.update).toHaveBeenCalledWith({
      where: { id: "account-1" },
      data: expect.objectContaining({
        accessTokenEncrypted: "encrypted:new-access",
        refreshTokenEncrypted: "encrypted:rotated-refresh",
        scopes: ["openid", "email", "profile", "mail-r", "mail-w"],
      }),
    });
  });

  it("requires reconnection after Yahoo revokes the refresh token", async () => {
    const { service, prisma } = setup(
      new Response(JSON.stringify({ error: "invalid_grant" }), {
        status: 400,
        headers: { "content-type": "application/json" },
      }),
    );

    await expect(service.getAccessToken("account-1")).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(prisma.emailAccount.update).toHaveBeenCalledWith({
      where: { id: "account-1" },
      data: {
        syncStatus: "DISCONNECTED",
        lastSyncError:
          "Yahoo access expired or was revoked. Reconnect Yahoo Mail to continue scanning.",
      },
    });
  });
});
