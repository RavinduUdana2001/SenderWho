import { JobStatus } from "@prisma/client";
import { PrismaService } from "../database/prisma.service";
import { GmailClient } from "../providers/gmail/gmail.client";
import { GmailSyncService } from "../providers/gmail/gmail-sync.service";
import { GoogleTokenService } from "../providers/google-token.service";
import { CleanupProcessor } from "./cleanup.processor";
import { ProcessorJob } from "./database-job-queue.service";

describe("CleanupProcessor retry state", () => {
  function setup(attemptsMade: number) {
    const prisma = {
      cleanupJob: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: "cleanup-1",
          userId: "user-1",
          emailAccountId: "account-1",
          status: JobStatus.QUEUED,
          processedMessages: 0,
          failedMessages: 0,
          metadata: { categories: ["SPAM"] },
        }),
        update: jest.fn().mockResolvedValue({}),
      },
      cleanupJobItem: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
        findMany: jest
          .fn()
          .mockRejectedValue(new Error("Database unavailable")),
      },
      auditLog: { create: jest.fn().mockResolvedValue({ id: "audit-1" }) },
    } as unknown as PrismaService;
    const processor = new CleanupProcessor(
      prisma,
      {} as GmailClient,
      {} as GoogleTokenService,
      {} as GmailSyncService,
    );
    const job = {
      data: { cleanupJobId: "cleanup-1" },
      attemptsMade,
      opts: { attempts: 3 },
    } as unknown as ProcessorJob<{ cleanupJobId: string }>;
    return { processor, prisma, job };
  }

  it("keeps an infrastructure failure queued while retries remain", async () => {
    const { processor, prisma, job } = setup(0);
    await expect(processor.process(job)).rejects.toThrow(
      "Database unavailable",
    );

    expect(prisma.cleanupJob.update).toHaveBeenLastCalledWith({
      where: { id: "cleanup-1" },
      data: {
        status: JobStatus.QUEUED,
        completedAt: null,
        activeKey: undefined,
      },
    });
  });

  it("marks an infrastructure failure final after the last retry", async () => {
    const { processor, prisma, job } = setup(2);
    await expect(processor.process(job)).rejects.toThrow(
      "Database unavailable",
    );

    expect(prisma.cleanupJob.update).toHaveBeenLastCalledWith({
      where: { id: "cleanup-1" },
      data: {
        status: JobStatus.FAILED,
        completedAt: expect.any(Date),
        activeKey: null,
      },
    });
  });

  it("does not replay Gmail mutations when audit logging fails after completion", async () => {
    const prisma = {
      cleanupJob: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: "cleanup-1",
          userId: "user-1",
          emailAccountId: "account-1",
          status: JobStatus.QUEUED,
          processedMessages: 0,
          failedMessages: 0,
          metadata: { categories: ["SPAM"] },
        }),
        findUnique: jest.fn().mockResolvedValue({
          status: JobStatus.RUNNING,
          emailAccount: { syncStatus: "READY" },
        }),
        update: jest.fn().mockResolvedValue({}),
      },
      cleanupJobItem: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
        findMany: jest.fn().mockResolvedValue([
          {
            id: "item-1",
            messageId: "message-1",
            providerMessageId: "gmail-1",
          },
        ]),
        update: jest.fn().mockResolvedValue({}),
        count: jest
          .fn()
          .mockImplementation(({ where }) =>
            Promise.resolve(where.status === "COMPLETED" ? 1 : 0),
          ),
      },
      message: {
        findFirst: jest.fn().mockResolvedValue({ id: "message-1" }),
        update: jest.fn().mockResolvedValue({}),
      },
      auditLog: {
        create: jest.fn().mockRejectedValue(new Error("Audit unavailable")),
      },
    } as unknown as PrismaService;
    const gmail = {
      trashMessage: jest.fn().mockResolvedValue(undefined),
    } as unknown as GmailClient;
    const tokens = {
      getAccessToken: jest.fn().mockResolvedValue("access-token"),
    } as unknown as GoogleTokenService;
    const gmailSync = {
      recalculateAccount: jest.fn().mockResolvedValue(undefined),
      refreshCleanupSuggestions: jest.fn().mockResolvedValue(undefined),
    } as unknown as GmailSyncService;
    const processor = new CleanupProcessor(prisma, gmail, tokens, gmailSync);
    const job = {
      data: { cleanupJobId: "cleanup-1" },
      attemptsMade: 0,
      opts: { attempts: 3 },
      updateProgress: jest.fn().mockResolvedValue(undefined),
    } as unknown as ProcessorJob<{ cleanupJobId: string }>;

    await expect(processor.process(job)).resolves.toMatchObject({
      status: JobStatus.COMPLETED,
      processedMessages: 1,
    });
    expect(gmail.trashMessage).toHaveBeenCalledTimes(1);
    expect(prisma.cleanupJob.update).toHaveBeenLastCalledWith({
      where: { id: "cleanup-1" },
      data: expect.objectContaining({
        status: JobStatus.COMPLETED,
        activeKey: null,
      }),
    });
  });
});
