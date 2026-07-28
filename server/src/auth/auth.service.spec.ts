import { ConfigService } from "@nestjs/config";
import { JwtService } from "@nestjs/jwt";
import { OAuthLoginStatus } from "@prisma/client";
import { createHash } from "node:crypto";
import { TokenEncryptionService } from "../common/security/token-encryption.service";
import { PrismaService } from "../database/prisma.service";
import { GmailClient } from "../providers/gmail/gmail.client";
import { InboxJobsService } from "../jobs/inbox-jobs.service";
import { AuthService } from "./auth.service";

describe("AuthService", () => {
  let service: AuthService;

  beforeEach(() => {
    const config = new ConfigService({
      oauth: {
        google: {
          clientId: "google-client-id",
          clientSecret: "google-client-secret",
          callbackUrl:
            "http://localhost:3000/api/v1/auth/oauth/google/callback",
        },
        yahoo: {
          enabled: true,
          clientId: "yahoo-client-id",
          clientSecret: "yahoo-client-secret",
          callbackUrl: "http://localhost:3000/api/v1/auth/oauth/yahoo/callback",
        },
      },
    });
    const jwtService = new JwtService({ secret: "test-jwt-secret" });
    const prisma = {
      mockDataEnabled: true,
      oAuthLoginSession: {
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
        create: jest.fn().mockResolvedValue({ id: "login-session" }),
      },
    } as unknown as PrismaService;
    const gmailClient = {} as GmailClient;
    const tokenEncryption = {
      encrypt: jest.fn().mockReturnValue("v2.test.encrypted-verifier"),
    } as unknown as TokenEncryptionService;
    const inboxJobs = {} as InboxJobsService;

    service = new AuthService(
      config,
      jwtService,
      prisma,
      gmailClient,
      tokenEncryption,
      inboxJobs,
    );
  });

  it("creates a secure Google OAuth authorization URL", async () => {
    const result = await service.startOAuth("google");
    const url = new URL(result.authorizationUrl);

    expect(url.origin).toBe("https://accounts.google.com");
    expect(url.searchParams.get("client_id")).toBe("google-client-id");
    expect(url.searchParams.get("access_type")).toBe("offline");
    expect(url.searchParams.get("prompt")).toBe("select_account");
    expect(url.searchParams.get("state")).toBeTruthy();
    expect(url.searchParams.get("nonce")).toBeTruthy();
    expect(url.searchParams.get("code_challenge")).toBeTruthy();
    expect(url.searchParams.get("code_challenge_method")).toBe("S256");
    expect(url.searchParams.get("scope")).toContain(
      "https://www.googleapis.com/auth/gmail.modify",
    );
  });

  it("publishes only OAuth providers that are ready for end users", () => {
    expect(service.availableProviders()).toEqual({
      providers: {
        google: { enabled: true },
        yahoo: { enabled: true },
      },
    });

    const disabledYahooService = new AuthService(
      new ConfigService({
        oauth: {
          yahoo: {
            enabled: false,
            clientId: "yahoo-client-id",
            clientSecret: "yahoo-client-secret",
            callbackUrl:
              "https://api.example.test/api/v1/auth/oauth/yahoo/callback",
          },
        },
      }),
      new JwtService({ secret: "a-test-secret-that-is-long-enough" }),
      {} as PrismaService,
      {} as GmailClient,
      {} as TokenEncryptionService,
      {} as InboxJobsService,
    );

    expect(disabledYahooService.availableProviders()).toEqual({
      providers: {
        google: { enabled: true },
        yahoo: { enabled: false },
      },
    });
  });

  it("creates a secure Yahoo OAuth authorization URL", async () => {
    const result = await service.startOAuth("yahoo");
    const url = new URL(result.authorizationUrl);

    expect(url.origin).toBe("https://api.login.yahoo.com");
    expect(url.searchParams.get("client_id")).toBe("yahoo-client-id");
    expect(url.searchParams.get("scope")).toContain("mail-r");
    expect(url.searchParams.get("scope")).toContain("mail-w");
    expect(url.searchParams.get("state")).toBeTruthy();
    expect(url.searchParams.get("nonce")).toBeTruthy();
    expect(url.searchParams.get("code_challenge")).toBeTruthy();
    expect(url.searchParams.get("code_challenge_method")).toBe("S256");
  });

  it("binds reauthentication to the current active app session", async () => {
    const prisma = {
      mockDataEnabled: false,
      appSession: {
        findFirst: jest.fn().mockResolvedValue({ id: "app-session-1" }),
      },
      oAuthLoginSession: {
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
        create: jest.fn().mockResolvedValue({ id: "login-session" }),
      },
    } as unknown as PrismaService;
    const sessionService = new AuthService(
      new ConfigService({
        oauth: {
          google: {
            clientId: "google-client-id",
            clientSecret: "google-client-secret",
            callbackUrl: "https://api.example.test/auth/oauth/google/callback",
          },
        },
      }),
      new JwtService({ secret: "a-test-secret-that-is-long-enough" }),
      prisma,
      {} as GmailClient,
      {
        encrypt: jest.fn().mockReturnValue("encrypted"),
      } as unknown as TokenEncryptionService,
      {} as InboxJobsService,
    );

    await sessionService.startReauthentication("user-1", "app-session-1");

    expect(prisma.appSession.findFirst).toHaveBeenCalledWith({
      where: {
        id: "app-session-1",
        userId: "user-1",
        revokedAt: null,
        expiresAt: { gt: expect.any(Date) },
      },
      select: { id: true },
    });
    expect(prisma.oAuthLoginSession.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        purpose: "REAUTH",
        userId: "user-1",
        appSessionId: "app-session-1",
      }),
      select: { id: true },
    });
  });

  it("refreshes recent-auth time without creating a new session family", async () => {
    const transaction = {
      oAuthLoginSession: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      appSession: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        create: jest.fn(),
      },
    };
    const sessionSecret = "reauth-secret";
    const prisma = {
      oAuthLoginSession: {
        findUnique: jest.fn().mockResolvedValue({
          id: "reauth-1",
          secretHash: createHash("sha256").update(sessionSecret).digest("hex"),
          purpose: "REAUTH",
          appSessionId: "app-session-1",
          status: OAuthLoginStatus.COMPLETED,
          expiresAt: new Date(Date.now() + 60_000),
          user: { id: "user-1", email: "person@example.com" },
        }),
      },
      $transaction: jest
        .fn()
        .mockImplementation((callback) => callback(transaction)),
    } as unknown as PrismaService;
    const sessionService = new AuthService(
      new ConfigService(),
      new JwtService({ secret: "a-test-secret-that-is-long-enough" }),
      prisma,
      {} as GmailClient,
      {} as TokenEncryptionService,
      {} as InboxJobsService,
    );

    const result = await sessionService.exchangeOAuthSession(
      "reauth-1",
      sessionSecret,
    );

    expect(result).toMatchObject({
      status: "REAUTHENTICATED",
      user: { id: "user-1", email: "person@example.com" },
    });
    expect(result).not.toHaveProperty("refreshToken");
    expect(transaction.appSession.updateMany).toHaveBeenCalledWith({
      where: expect.objectContaining({
        id: "app-session-1",
        userId: "user-1",
        revokedAt: null,
      }),
      data: {
        authenticatedAt: expect.any(Date),
        lastUsedAt: expect.any(Date),
      },
    });
    expect(transaction.appSession.create).not.toHaveBeenCalled();
  });

  it("rejects a callback without signed state", async () => {
    await expect(
      service.handleOAuthCallback("google", "sample-code"),
    ).rejects.toThrow("OAuth state is missing.");
  });

  it("rotates refresh tokens and stores only the replacement hash", async () => {
    const transaction = {
      appSession: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        create: jest.fn().mockResolvedValue({ id: "next-session" }),
        update: jest.fn().mockResolvedValue({ id: "current-session" }),
      },
    };
    const prisma = {
      appSession: {
        findUnique: jest.fn().mockResolvedValue({
          id: "current-session",
          familyId: "family-1",
          authenticatedAt: new Date(),
          revokedAt: null,
          expiresAt: new Date(Date.now() + 60_000),
          user: {
            id: "user-1",
            email: "person@example.com",
            deletedAt: null,
          },
        }),
      },
      $transaction: jest
        .fn()
        .mockImplementation((callback) => callback(transaction)),
    } as unknown as PrismaService;
    const sessionService = new AuthService(
      new ConfigService({ auth: { refreshTokenDays: 365 } }),
      new JwtService({ secret: "a-test-secret-that-is-long-enough" }),
      prisma,
      {} as GmailClient,
      {} as TokenEncryptionService,
      {} as InboxJobsService,
    );

    const result = await sessionService.refreshSession("old-refresh-token");

    expect(result.status).toBe("AUTHENTICATED");
    expect(result.refreshToken).not.toBe("old-refresh-token");
    expect(transaction.appSession.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ id: "current-session" }),
      }),
    );
    expect(transaction.appSession.update).toHaveBeenCalledWith({
      where: { id: "current-session" },
      data: { replacedById: "next-session" },
    });
    const createCall = transaction.appSession.create.mock.calls[0][0];
    expect(createCall.data.tokenHash).toHaveLength(64);
    expect(createCall.data.tokenHash).not.toBe(result.refreshToken);
    const remainingDays =
      (createCall.data.expiresAt.getTime() - Date.now()) /
      (24 * 60 * 60 * 1_000);
    expect(remainingDays).toBeGreaterThan(364.9);
    expect(remainingDays).toBeLessThanOrEqual(365);
  });

  it("rejects a refresh token that loses the atomic rotation race", async () => {
    const transaction = {
      appSession: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
        create: jest.fn(),
      },
    };
    const prisma = {
      appSession: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        findUnique: jest.fn().mockResolvedValue({
          id: "current-session",
          familyId: "family-1",
          authenticatedAt: new Date(),
          revokedAt: null,
          expiresAt: new Date(Date.now() + 60_000),
          user: {
            id: "user-1",
            email: "person@example.com",
            deletedAt: null,
          },
        }),
      },
      $transaction: jest
        .fn()
        .mockImplementation((callback) => callback(transaction)),
      auditLog: { create: jest.fn().mockResolvedValue({ id: "audit-1" }) },
    } as unknown as PrismaService;
    const sessionService = new AuthService(
      new ConfigService({ auth: { refreshTokenDays: 90 } }),
      new JwtService({ secret: "a-test-secret-that-is-long-enough" }),
      prisma,
      {} as GmailClient,
      {} as TokenEncryptionService,
      {} as InboxJobsService,
    );

    await expect(
      sessionService.refreshSession("already-used-token"),
    ).rejects.toThrow("already used");
    expect(transaction.appSession.create).not.toHaveBeenCalled();
  });

  it("still reports refresh-token reuse when the audit store is unavailable", async () => {
    const prisma = {
      appSession: {
        findUnique: jest.fn().mockResolvedValue({
          id: "reused-session",
          familyId: "family-1",
          revokedAt: new Date(),
          expiresAt: new Date(Date.now() + 60_000),
          user: {
            id: "user-1",
            email: "person@example.com",
            deletedAt: null,
          },
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      auditLog: {
        create: jest.fn().mockRejectedValue(new Error("audit unavailable")),
      },
    } as unknown as PrismaService;
    const sessionService = new AuthService(
      new ConfigService({ auth: { refreshTokenDays: 90 } }),
      new JwtService({ secret: "a-test-secret-that-is-long-enough" }),
      prisma,
      {} as GmailClient,
      {} as TokenEncryptionService,
      {} as InboxJobsService,
    );

    await expect(sessionService.refreshSession("reused-token")).rejects.toThrow(
      "already used",
    );
    expect(prisma.appSession.updateMany).toHaveBeenCalledWith({
      where: { familyId: "family-1", revokedAt: null },
      data: {
        revokedAt: expect.any(Date),
        revocationReason: "TOKEN_REUSE",
      },
    });
  });

  it("signs out only the app session without disconnecting Gmail", async () => {
    const prisma = {
      appSession: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    } as unknown as PrismaService;
    const sessionService = new AuthService(
      new ConfigService({ auth: { refreshTokenDays: 90 } }),
      new JwtService({ secret: "a-test-secret-that-is-long-enough" }),
      prisma,
      {} as GmailClient,
      {} as TokenEncryptionService,
      {} as InboxJobsService,
    );

    await expect(sessionService.logout("refresh-token")).resolves.toEqual({
      success: true,
      refreshTokenRevoked: true,
    });
    expect(prisma.appSession.updateMany).toHaveBeenCalledTimes(1);
  });
});
