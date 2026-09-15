import { UnauthorizedException } from "@nestjs/common";
import { MicrosoftTokenService } from "./microsoft-token.service";

describe("MicrosoftTokenService", () => {
  afterEach(() => jest.restoreAllMocks());

  function setup(response: Response) {
    const config = {
      get: jest.fn((key: string) => {
        if (key === "oauth.microsoft.clientId") return "microsoft-client";
        if (key === "oauth.microsoft.clientSecret") return "microsoft-secret";
        return undefined;
      }),
    };
    const prisma = {
      emailAccount: {
        findUnique: jest.fn().mockResolvedValue({
          provider: "MICROSOFT",
          providerAccountId: "microsoft-account-1",
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
    jest.spyOn(global, "fetch").mockResolvedValue(response);
    return {
      service: new MicrosoftTokenService(
        config as never,
        prisma as never,
        encryption as never,
      ),
      prisma,
    };
  }

  it("refreshes and persists rotated Microsoft OAuth tokens", async () => {
    const { service, prisma } = setup(
      new Response(
        JSON.stringify({
          access_token: "new-access",
          refresh_token: "rotated-refresh",
          expires_in: 3600,
          scope: "openid User.Read Mail.ReadWrite offline_access",
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
        scopes: ["openid", "User.Read", "Mail.ReadWrite", "offline_access"],
      }),
    });
  });

  it("requires reconnection when Microsoft revokes offline access", async () => {
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
          "Microsoft Outlook access expired or was revoked. Reconnect Outlook to continue scanning.",
      },
    });
  });
});
