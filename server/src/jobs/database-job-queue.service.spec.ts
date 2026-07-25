import { BackgroundJob, BackgroundJobStatus } from "@prisma/client";
import { PrismaService } from "../database/prisma.service";
import { DatabaseJobQueueService } from "./database-job-queue.service";

describe("DatabaseJobQueueService", () => {
  it("deduplicates an already active job", async () => {
    const active = {
      id: "cleanup-1",
      queue: "cleanup",
      status: BackgroundJobStatus.RUNNING,
    };
    const prisma = {
      mockDataEnabled: false,
      backgroundJob: {
        findUnique: jest.fn().mockResolvedValue(active),
        create: jest.fn(),
        update: jest.fn(),
      },
    } as unknown as PrismaService;
    const service = new DatabaseJobQueueService(prisma);

    const job = await service.add(
      "cleanup",
      "trash-cleanup-messages",
      { cleanupJobId: "1" },
      { jobId: "cleanup-1" },
    );

    expect(job.id).toBe("cleanup-1");
    expect(prisma.backgroundJob.create).not.toHaveBeenCalled();
    expect(prisma.backgroundJob.update).not.toHaveBeenCalled();
  });

  it("claims a queued job with an expiring lease and increments attempts", async () => {
    const claimed = {
      id: "scan-1",
      queue: "scan-inbox",
      status: BackgroundJobStatus.RUNNING,
    };
    const prisma = {
      mockDataEnabled: false,
      backgroundJob: {
        findFirst: jest.fn().mockResolvedValue({ id: "scan-1" }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        findUnique: jest.fn().mockResolvedValue(claimed),
      },
    } as unknown as PrismaService;
    const service = new DatabaseJobQueueService(prisma);

    await expect(
      service.claim("scan-inbox", "worker-1", 120_000),
    ).resolves.toEqual(claimed);
    expect(prisma.backgroundJob.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          status: BackgroundJobStatus.RUNNING,
          attempts: { increment: 1 },
          leaseOwner: "worker-1",
          leaseExpiresAt: expect.any(Date),
        }),
      }),
    );
  });

  it("returns expired running jobs to the queue", async () => {
    const updateMany = jest.fn().mockResolvedValue({ count: 2 });
    const prisma = {
      mockDataEnabled: false,
      backgroundJob: { updateMany },
    } as unknown as PrismaService;
    const service = new DatabaseJobQueueService(prisma);

    await expect(service.recoverExpiredLeases()).resolves.toBe(2);
    expect(updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          status: BackgroundJobStatus.RUNNING,
          leaseExpiresAt: { lt: expect.any(Date) },
        }),
        data: expect.objectContaining({
          status: BackgroundJobStatus.QUEUED,
          leaseOwner: null,
        }),
      }),
    );
  });

  it("uses exponential delayed retries and stops at max attempts", async () => {
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const prisma = {
      mockDataEnabled: false,
      backgroundJob: { updateMany },
    } as unknown as PrismaService;
    const service = new DatabaseJobQueueService(prisma);
    const record = {
      id: "scan-1",
      attempts: 2,
      maxAttempts: 4,
      backoffMs: 2_000,
    } as BackgroundJob;

    await service.fail(record, "worker-1", new Error("temporary"));
    expect(updateMany).toHaveBeenLastCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          status: BackgroundJobStatus.QUEUED,
          availableAt: expect.any(Date),
          completedAt: null,
        }),
      }),
    );

    await service.fail(
      { ...record, attempts: 4 },
      "worker-1",
      new Error("final"),
    );
    expect(updateMany).toHaveBeenLastCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          status: BackgroundJobStatus.FAILED,
          completedAt: expect.any(Date),
        }),
      }),
    );
  });
});
