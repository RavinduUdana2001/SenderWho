import { CleanupCategory, JobStatus } from "@prisma/client";
import { buildCleanupMessageWhere, CleanupService } from "./cleanup.service";

describe("CleanupService preview", () => {
  it("returns an exact unique preview scoped to the owned account", async () => {
    const prisma = {
      emailAccount: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: "account-1", userId: "user-1" }),
      },
      message: {
        findMany: jest.fn().mockResolvedValue(
          Array.from({ length: 12 }, (_, index) => ({
            id: `message-${index + 1}`,
            sizeBytes: index === 0 ? 4_096 : 0,
          })),
        ),
      },
      cleanupPlan: {
        create: jest.fn().mockResolvedValue({ id: "preview-1" }),
      },
    };
    const service = new CleanupService(prisma as never, {} as never);

    await expect(
      service.preview("user-1", {
        emailAccountId: "account-1",
        categories: ["PROMOTIONS", "NEWSLETTERS", "PROMOTIONS"],
      }),
    ).resolves.toEqual({
      previewId: "preview-1",
      emailAccountId: "account-1",
      categories: [CleanupCategory.MARKETING, CleanupCategory.NEWSLETTERS],
      totalMessages: 12,
      estimatedSpaceBytes: 4_096,
    });
    expect(prisma.emailAccount.findFirst).toHaveBeenCalledWith({
      where: { id: "account-1", userId: "user-1" },
      select: { id: true, userId: true },
    });
    expect(prisma.message.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          emailAccountId: "account-1",
          isTrashed: false,
          category: { not: "IMPORTANT" },
          isImportant: false,
          sender: { isTrusted: false },
        }),
      }),
    );
    expect(prisma.cleanupPlan.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        userId: "user-1",
        emailAccountId: "account-1",
        categories: [CleanupCategory.MARKETING, CleanupCategory.NEWSLETTERS],
        messageIds: expect.arrayContaining(["message-1", "message-12"]),
        totalMessages: 12,
        estimatedSpaceBytes: 4_096,
        expiresAt: expect.any(Date),
      }),
    });
  });

  it("protects important and trusted messages for every cleanup category", () => {
    const where = buildCleanupMessageWhere("account-1", [
      CleanupCategory.OLD_UNREAD,
      CleanupCategory.LARGE_ATTACHMENTS,
    ]);

    expect(where).toEqual(
      expect.objectContaining({
        emailAccountId: "account-1",
        isTrashed: false,
        isImportant: false,
        category: { not: "IMPORTANT" },
        sender: { isTrusted: false },
      }),
    );
  });

  it("replaces an orphaned legacy job using only the unexpired reviewed snapshot", async () => {
    const cleanupJob = {
      id: "job-1",
      userId: "user-1",
      emailAccountId: "account-1",
      status: JobStatus.QUEUED,
      totalMessages: 2,
    };
    const prismaCore = {
      emailAccount: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: "account-1", userId: "user-1" }),
      },
      cleanupPlan: {
        findFirst: jest.fn().mockResolvedValue({
          id: "preview-1",
          categories: [CleanupCategory.MARKETING],
          messageIds: ["message-1", "message-2"],
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      cleanupJob: {
        findFirst: jest.fn().mockResolvedValue({
          id: "legacy-job",
          status: JobStatus.RUNNING,
          totalMessages: 10,
          processedMessages: 4,
          failedMessages: 0,
          _count: { items: 0 },
        }),
        update: jest.fn().mockResolvedValue({ id: "legacy-job" }),
        create: jest.fn().mockResolvedValue(cleanupJob),
      },
      cleanupJobItem: {
        createMany: jest.fn().mockResolvedValue({ count: 2 }),
      },
      message: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: "message-1",
            providerMessageId: "gmail-1",
            sizeBytes: 1_024,
          },
          { id: "message-2", providerMessageId: "gmail-2", sizeBytes: null },
        ]),
      },
      auditLog: { create: jest.fn().mockResolvedValue({ id: "audit-1" }) },
    };
    const prisma = {
      ...prismaCore,
      $transaction: jest.fn(
        async (work: (tx: unknown) => Promise<unknown>): Promise<unknown> =>
          work(prismaCore),
      ),
    };
    const queue = {
      getJob: jest.fn().mockResolvedValue(null),
      add: jest.fn().mockResolvedValue({ id: "queue-1" }),
    };
    const service = new CleanupService(prisma as never, queue as never);

    await expect(
      service.createJob("user-1", {
        emailAccountId: "account-1",
        categories: ["MARKETING"],
        previewId: "preview-1",
      }),
    ).resolves.toMatchObject({ id: "job-1", queueJobId: "queue-1" });

    expect(prisma.message.findMany).toHaveBeenCalledWith({
      where: expect.objectContaining({
        id: { in: ["message-1", "message-2"] },
        emailAccountId: "account-1",
        isImportant: false,
      }),
      select: { id: true, providerMessageId: true, sizeBytes: true },
    });
    expect(prisma.cleanupJobItem.createMany).toHaveBeenCalledWith({
      data: [
        {
          cleanupJobId: "job-1",
          messageId: "message-1",
          providerMessageId: "gmail-1",
          sizeBytes: 1_024,
        },
        {
          cleanupJobId: "job-1",
          messageId: "message-2",
          providerMessageId: "gmail-2",
          sizeBytes: 0,
        },
      ],
    });
    expect(prisma.cleanupJob.update).toHaveBeenCalledWith({
      where: { id: "legacy-job" },
      data: expect.objectContaining({
        status: JobStatus.FAILED,
        failedMessages: 6,
        activeKey: null,
      }),
    });
  });

  it("does not preview cleanup data for another user's account", async () => {
    const prisma = {
      emailAccount: { findFirst: jest.fn().mockResolvedValue(null) },
    };
    const service = new CleanupService(prisma as never, {} as never);

    await expect(
      service.preview("owner", {
        emailAccountId: "foreign-account",
        categories: ["SPAM"],
      }),
    ).rejects.toThrow("not found");
  });

  it("restores only active cleanup jobs owned by the current user", async () => {
    const prisma = {
      cleanupJob: { findMany: jest.fn().mockResolvedValue([]) },
    };
    const service = new CleanupService(prisma as never, {} as never);

    await expect(service.getActiveJobs("user-1")).resolves.toEqual({
      items: [],
    });
    expect(prisma.cleanupJob.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          userId: "user-1",
          status: { in: [JobStatus.QUEUED, JobStatus.RUNNING] },
        },
      }),
    );
  });

  it("finalizes a legacy active job that has no recoverable item snapshot", async () => {
    const orphaned = {
      id: "legacy-job",
      status: JobStatus.RUNNING,
      totalMessages: 20,
      processedMessages: 8,
      failedMessages: 1,
      startedAt: new Date(),
      completedAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      _count: { items: 0 },
    };
    const prisma = {
      cleanupJob: {
        findFirst: jest.fn().mockResolvedValue(orphaned),
        update: jest.fn().mockResolvedValue({
          ...orphaned,
          status: JobStatus.FAILED,
          failedMessages: 12,
          completedAt: new Date(),
          _count: undefined,
        }),
      },
    };
    const queue = { getJob: jest.fn(), add: jest.fn() };
    const service = new CleanupService(prisma as never, queue as never);

    await expect(service.getJob("user-1", "legacy-job")).resolves.toMatchObject(
      {
        id: "legacy-job",
        status: JobStatus.FAILED,
        processedMessages: 8,
        failedMessages: 12,
      },
    );
    expect(prisma.cleanupJob.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: "legacy-job" },
        data: expect.objectContaining({
          status: JobStatus.FAILED,
          failedMessages: 12,
          activeKey: null,
        }),
      }),
    );
    expect(queue.getJob).not.toHaveBeenCalled();
  });

  it("requeues a valid active snapshot when its durable job is missing", async () => {
    const active = {
      id: "recoverable-job",
      status: JobStatus.QUEUED,
      totalMessages: 2,
      processedMessages: 0,
      failedMessages: 0,
      startedAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      _count: { items: 2 },
    };
    const prisma = {
      cleanupJob: { findMany: jest.fn().mockResolvedValue([active]) },
    };
    const queue = {
      getJob: jest.fn().mockResolvedValue(null),
      add: jest.fn().mockResolvedValue({ id: "cleanup-recoverable-job" }),
    };
    const service = new CleanupService(prisma as never, queue as never);

    await expect(service.getActiveJobs("user-1")).resolves.toEqual({
      items: [expect.not.objectContaining({ _count: expect.anything() })],
    });
    expect(queue.add).toHaveBeenCalledWith(
      "cleanup",
      "trash-cleanup-messages",
      { cleanupJobId: "recoverable-job" },
      expect.objectContaining({ jobId: "cleanup-recoverable-job" }),
    );
  });
});
