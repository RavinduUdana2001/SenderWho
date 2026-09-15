import { EmailAccountsService } from "./email-accounts.service";

describe("EmailAccountsService ownership", () => {
  function setup() {
    const prisma = {
      mockDataEnabled: false,
      emailAccount: {
        findFirst: jest.fn().mockResolvedValue(null),
        update: jest.fn(),
      },
      auditLog: { create: jest.fn() },
    };
    const inboxJobs = { enqueueScan: jest.fn() };
    const encryption = { decrypt: jest.fn() };
    return {
      prisma,
      inboxJobs,
      encryption,
      service: new EmailAccountsService(
        prisma as never,
        inboxJobs as never,
        encryption as never,
      ),
    };
  }

  it("rejects a cross-user sync ID before queueing work", async () => {
    const { prisma, inboxJobs, service } = setup();

    await expect(
      service.queueSync("owner-user", "foreign-account"),
    ).rejects.toThrow("not found");

    expect(prisma.emailAccount.findFirst).toHaveBeenCalledWith({
      where: { id: "foreign-account", userId: "owner-user" },
      select: { id: true, provider: true, syncStatus: true },
    });
    expect(inboxJobs.enqueueScan).not.toHaveBeenCalled();
    expect(prisma.emailAccount.update).not.toHaveBeenCalled();
  });

  it("rejects a cross-user disconnect before token access or mutation", async () => {
    const { prisma, encryption, service } = setup();

    await expect(
      service.disconnect("owner-user", "foreign-account"),
    ).rejects.toThrow("not found");

    expect(prisma.emailAccount.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: "foreign-account", userId: "owner-user" },
      }),
    );
    expect(encryption.decrypt).not.toHaveBeenCalled();
    expect(prisma.emailAccount.update).not.toHaveBeenCalled();
  });

  it("does not report a queued Gmail scan as failed when only audit storage fails", async () => {
    const { prisma, inboxJobs, service } = setup();
    prisma.emailAccount.findFirst.mockResolvedValue({
      id: "account-1",
      provider: "GOOGLE",
    });
    prisma.emailAccount.update.mockResolvedValue({});
    inboxJobs.enqueueScan.mockResolvedValue({
      jobId: "scan-1",
      status: "QUEUED",
    });
    prisma.auditLog.create.mockRejectedValue(new Error("Audit unavailable"));

    await expect(service.queueSync("user-1", "account-1")).resolves.toEqual({
      emailAccountId: "account-1",
      queue: "scan-inbox",
      jobId: "scan-1",
      status: "QUEUED",
    });
    expect(prisma.emailAccount.update).toHaveBeenCalledTimes(1);
    expect(prisma.emailAccount.update).toHaveBeenCalledWith({
      where: { id: "account-1" },
      data: { syncStatus: "PENDING", lastSyncError: null },
    });
  });

  it("cancels active destructive jobs before disconnect completes", async () => {
    const disconnected = { id: "account-1", syncStatus: "DISCONNECTED" };
    const prisma = {
      mockDataEnabled: false,
      emailAccount: {
        findFirst: jest.fn().mockResolvedValue({
          id: "account-1",
          providerAccountId: "google-1",
          refreshTokenEncrypted: null,
          accessTokenEncrypted: null,
        }),
        update: jest.fn().mockResolvedValue(disconnected),
      },
      cleanupJob: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      unsubscribeJob: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      auditLog: { create: jest.fn().mockResolvedValue({}) },
      $transaction: jest
        .fn()
        .mockImplementation((operations: Array<Promise<unknown>>) =>
          Promise.all(operations),
        ),
    };
    const service = new EmailAccountsService(
      prisma as never,
      {} as never,
      {} as never,
    );

    await expect(service.disconnect("user-1", "account-1")).resolves.toEqual({
      ...disconnected,
      isActive: false,
      providerRevoked: false,
    });
    expect(prisma.cleanupJob.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ emailAccountId: "account-1" }),
        data: expect.objectContaining({ status: "CANCELED", activeKey: null }),
      }),
    );
    expect(prisma.unsubscribeJob.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          sender: { emailAccountId: "account-1" },
        }),
        data: expect.objectContaining({ status: "CANCELED" }),
      }),
    );
  });

  it("rejects switching to an account owned by another user", async () => {
    const { prisma, service } = setup();

    await expect(
      service.activate("owner-user", "foreign-account"),
    ).rejects.toThrow("not found");
    expect(prisma.emailAccount.findFirst).toHaveBeenCalledWith({
      where: { id: "foreign-account", userId: "owner-user" },
      select: { id: true, emailAddress: true, syncStatus: true },
    });
  });

  it("selects a safe current mailbox for existing multi-account users", async () => {
    const accounts = [
      {
        id: "account-2",
        provider: "YAHOO",
        emailAddress: "second@example.com",
        displayName: "Second",
        isPrimary: false,
        syncStatus: "READY",
        lastSyncedAt: null,
        lastSyncError: null,
        syncStartedAt: null,
        backfillComplete: true,
        backfillProcessed: 10,
        createdAt: new Date(),
      },
      {
        id: "account-1",
        provider: "GOOGLE",
        emailAddress: "first@example.com",
        displayName: "First",
        isPrimary: false,
        syncStatus: "READY",
        lastSyncedAt: null,
        lastSyncError: null,
        syncStartedAt: null,
        backfillComplete: true,
        backfillProcessed: 20,
        createdAt: new Date(),
      },
    ];
    const prisma = {
      mockDataEnabled: false,
      emailAccount: {
        findMany: jest.fn().mockResolvedValue(accounts),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
        update: jest.fn().mockResolvedValue({ id: "account-2" }),
      },
      $transaction: jest
        .fn()
        .mockImplementation((operations: Array<Promise<unknown>>) =>
          Promise.all(operations),
        ),
    };
    const service = new EmailAccountsService(
      prisma as never,
      {} as never,
      {} as never,
    );

    const result = await service.listForCurrentUser("user-1");

    expect(result.items).toEqual([
      expect.objectContaining({ id: "account-2", isActive: true }),
      expect.objectContaining({ id: "account-1", isActive: false }),
    ]);
    expect(prisma.emailAccount.update).toHaveBeenCalledWith({
      where: { id: "account-2" },
      data: { isPrimary: true },
    });
  });

  it("switches the current mailbox in one transaction", async () => {
    const prisma = {
      mockDataEnabled: false,
      emailAccount: {
        findFirst: jest.fn().mockResolvedValue({
          id: "account-2",
          emailAddress: "second@example.com",
          syncStatus: "READY",
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        update: jest.fn().mockResolvedValue({
          id: "account-2",
          isPrimary: true,
        }),
      },
      auditLog: { create: jest.fn().mockResolvedValue({}) },
      $transaction: jest
        .fn()
        .mockImplementation((operations: Array<Promise<unknown>>) =>
          Promise.all(operations),
        ),
    };
    const service = new EmailAccountsService(
      prisma as never,
      {} as never,
      {} as never,
    );

    await expect(service.activate("user-1", "account-2")).resolves.toEqual({
      id: "account-2",
      emailAddress: "second@example.com",
      isActive: true,
    });
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(prisma.emailAccount.updateMany).toHaveBeenCalledWith({
      where: {
        userId: "user-1",
        isPrimary: true,
        id: { not: "account-2" },
      },
      data: { isPrimary: false },
    });
    expect(prisma.emailAccount.update).toHaveBeenCalledWith({
      where: { id: "account-2" },
      data: { isPrimary: true },
    });
  });
});
