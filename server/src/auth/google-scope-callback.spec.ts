import { ConfigService } from "@nestjs/config";
import { JwtService } from "@nestjs/jwt";
import { AuthService } from "./auth.service";

const profile = "https://www.googleapis.com/auth/userinfo.profile";
const email = "https://www.googleapis.com/auth/userinfo.email";
const gmail = "https://www.googleapis.com/auth/gmail.modify";

function setup(scope?: string) {
  const prisma = {
    mockDataEnabled: false,
    emailAccount: {
      findUnique: jest.fn().mockResolvedValue({
        id: "mailbox",
        userId: "owner",
        refreshTokenEncrypted: "stored",
      }),
      upsert: jest.fn().mockResolvedValue({ id: "mailbox" }),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      update: jest.fn().mockResolvedValue({ id: "mailbox" }),
    },
    oAuthLoginSession: {
      update: jest.fn().mockResolvedValue({}),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    auditLog: { create: jest.fn().mockResolvedValue({}) },
    $transaction: jest.fn((operations: Promise<unknown>[]) =>
      Promise.all(operations),
    ),
  };
  const jobs = {
    enqueueScan: jest
      .fn()
      .mockResolvedValue({ jobId: "scan", status: "QUEUED" }),
  };
  const service = new AuthService(
    new ConfigService({
      oauth: {
        google: {
          clientId: "client",
          clientSecret: "secret",
          callbackUrl: "https://example.test/callback",
        },
      },
    }),
    new JwtService({ secret: "test-secret" }),
    prisma as never,
    {
      getProfile: jest
        .fn()
        .mockResolvedValue({ emailAddress: "second@example.test" }),
    } as never,
    {
      decrypt: jest.fn().mockReturnValue("verifier"),
      encrypt: jest.fn().mockReturnValue("encrypted"),
    } as never,
    jobs as never,
  );
  jest.spyOn(service as never, "verifyState").mockResolvedValue({
    id: "login",
    purpose: "ADD_ACCOUNT",
    userId: "owner",
    nonceHash: "nonce",
    pkceVerifierEncrypted: "verifier",
  } as never);
  jest.spyOn(service as never, "exchangeGoogleCode").mockResolvedValue({
    access_token: "access",
    refresh_token: "refresh",
    id_token: "identity",
    scope,
  } as never);
  jest.spyOn(service as never, "validateGoogleIdToken").mockResolvedValue({
    sub: "google-owner",
    email: "second@example.test",
  } as never);
  jest
    .spyOn(service as never, "accountConnectionUser")
    .mockResolvedValue({ id: "owner" } as never);
  return { service, prisma, jobs };
}

describe("Google callback scope aliases", () => {
  it.each([
    ["canonical UserInfo URLs", `openid ${profile} ${email} ${gmail}`],
    ["short OpenID aliases", `openid profile email ${gmail}`],
    ["mixed identity scope names", `openid profile ${email} ${gmail}`],
    ["token scope whitespace", `  openid\t${profile}\n${email}  ${gmail} `],
  ])("reconnects and queues a mailbox scan with %s", async (_name, scopes) => {
    const { service, prisma, jobs } = setup(scopes);
    await expect(
      service.handleOAuthCallback("google", "code", "state"),
    ).resolves.toMatchObject({
      success: true,
      emailAccountId: "mailbox",
      persisted: true,
    });
    expect(prisma.emailAccount.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        update: expect.objectContaining({
          userId: "owner",
          syncStatus: "PENDING",
          lastSyncError: null,
        }),
      }),
    );
    expect(jobs.enqueueScan).toHaveBeenCalledWith("mailbox");
  });

  it.each([
    ["missing Gmail permission", `openid ${profile} ${email}`],
    [
      "read-only Gmail permission",
      `openid ${profile} ${email} https://www.googleapis.com/auth/gmail.readonly`,
    ],
    ["missing OpenID", `${profile} ${email} ${gmail}`],
    ["missing email", `openid ${profile} ${gmail}`],
    ["missing profile", `openid ${email} ${gmail}`],
    ["lookalike profile URI", `openid ${profile}.invalid ${email} ${gmail}`],
    [
      "case-changed Gmail URI",
      `openid ${profile} ${email} ${gmail.toUpperCase()}`,
    ],
    ["no granted scopes", undefined],
  ])(
    "still rejects %s before saving credentials or queuing a scan",
    async (_name, scopes) => {
      const { service, prisma, jobs } = setup(scopes);
      await expect(
        service.handleOAuthCallback("google", "code", "state"),
      ).rejects.toThrow(
        "Google did not grant all required SenderWho permissions.",
      );
      expect(prisma.emailAccount.upsert).not.toHaveBeenCalled();
      expect(jobs.enqueueScan).not.toHaveBeenCalled();
      expect(prisma.oAuthLoginSession.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: "FAILED" }),
        }),
      );
    },
  );
});
