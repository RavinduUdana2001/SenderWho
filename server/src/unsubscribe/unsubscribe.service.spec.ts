import { JobStatus, UnsubscribeMethod } from "@prisma/client";
import { UnsubscribeService } from "./unsubscribe.service";

describe("UnsubscribeService job dispatch", () => {
  const sender = {
    id: "sender-1",
    userId: "user-1",
    messages: [
      {
        listUnsubscribeUrl: "https://public.example/unsubscribe",
        providerMessageId: "gmail-1",
      },
    ],
  };
  const queuedJob = {
    id: "unsubscribe-1",
    userId: "user-1",
    senderId: "sender-1",
    status: JobStatus.QUEUED,
    method: UnsubscribeMethod.LIST_UNSUBSCRIBE_HEADER,
  };

  it("keeps a successfully queued operation successful when audit storage fails", async () => {
    const prisma = {
      mockDataEnabled: false,
      unsubscribeJob: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue(queuedJob),
      },
      sender: { findFirst: jest.fn().mockResolvedValue(sender) },
      auditLog: {
        create: jest.fn().mockRejectedValue(new Error("Audit unavailable")),
      },
    };
    const queue = {
      getJob: jest.fn().mockResolvedValue(null),
      add: jest.fn().mockResolvedValue({ id: "queue-1" }),
    };
    const service = new UnsubscribeService(prisma as never, queue as never);

    await expect(
      service.createJob("user-1", "sender-1"),
    ).resolves.toMatchObject({ id: "unsubscribe-1", queueJobId: "queue-1" });
    expect(queue.add).toHaveBeenCalledWith(
      "unsubscribe",
      "one-click-unsubscribe",
      { unsubscribeJobId: "unsubscribe-1" },
      expect.objectContaining({
        jobId: "unsubscribe-unsubscribe-1",
        attempts: 1,
      }),
    );
  });

  it("reuses a failed operation row for an explicit user retry", async () => {
    const failedJob = { ...queuedJob, status: JobStatus.FAILED };
    const prisma = {
      mockDataEnabled: false,
      unsubscribeJob: {
        findFirst: jest.fn().mockResolvedValue(failedJob),
        update: jest.fn().mockResolvedValue(queuedJob),
        create: jest.fn(),
      },
      sender: { findFirst: jest.fn().mockResolvedValue(sender) },
      auditLog: { create: jest.fn().mockResolvedValue({}) },
    };
    const staleQueueJob = {
      getState: jest.fn().mockResolvedValue("failed"),
      remove: jest.fn().mockResolvedValue(undefined),
    };
    const queue = {
      getJob: jest.fn().mockResolvedValue(staleQueueJob),
      add: jest.fn().mockResolvedValue({ id: "queue-1" }),
    };
    const service = new UnsubscribeService(prisma as never, queue as never);

    await expect(
      service.createJob("user-1", "sender-1"),
    ).resolves.toMatchObject({ status: JobStatus.QUEUED });
    expect(prisma.unsubscribeJob.update).toHaveBeenCalledWith({
      where: { id: "unsubscribe-1" },
      data: expect.objectContaining({
        status: JobStatus.QUEUED,
        operationKey: "user-1:sender-1",
        metadata: { providerMessageId: "gmail-1", retryAttempt: 1 },
      }),
    });
    expect(prisma.unsubscribeJob.create).not.toHaveBeenCalled();
    expect(staleQueueJob.remove).toHaveBeenCalledTimes(1);
    expect(queue.add).toHaveBeenCalledWith(
      "unsubscribe",
      "one-click-unsubscribe",
      { unsubscribeJobId: "unsubscribe-1" },
      expect.objectContaining({
        jobId: "unsubscribe-unsubscribe-1-attempt-1",
      }),
    );
  });

  it("creates a bounded batch with explicit partial-failure results", async () => {
    const service = new UnsubscribeService({} as never, {} as never);
    jest
      .spyOn(service, "createJob")
      .mockResolvedValueOnce(queuedJob as never)
      .mockRejectedValueOnce(new Error("foreign or invalid sender"));

    await expect(
      service.createJobs("user-1", ["sender-1", "sender-2"]),
    ).resolves.toEqual({
      requested: 2,
      queued: 1,
      failed: 1,
      jobs: [queuedJob],
      failures: [
        {
          senderId: "sender-2",
          reason: "This unsubscribe request could not be queued.",
        },
      ],
    });
    expect(service.createJob).toHaveBeenNthCalledWith(1, "user-1", "sender-1");
    expect(service.createJob).toHaveBeenNthCalledWith(2, "user-1", "sender-2");
  });

  it("restores a queued database job when its failed queue entry is stale", async () => {
    const staleQueueJob = {
      getState: jest.fn().mockResolvedValue("failed"),
      remove: jest.fn().mockResolvedValue(undefined),
    };
    const prisma = {
      mockDataEnabled: false,
      unsubscribeJob: {
        findMany: jest.fn().mockResolvedValue([queuedJob]),
      },
    };
    const queue = {
      getJob: jest.fn().mockResolvedValue(staleQueueJob),
      add: jest.fn().mockResolvedValue({ id: "queue-restored" }),
    };
    const service = new UnsubscribeService(prisma as never, queue as never);

    await expect(service.getActiveJobs("user-1")).resolves.toEqual({
      items: [queuedJob],
    });
    expect(staleQueueJob.remove).toHaveBeenCalledTimes(1);
    expect(queue.add).toHaveBeenCalledWith(
      "unsubscribe",
      "one-click-unsubscribe",
      { unsubscribeJobId: "unsubscribe-1" },
      expect.objectContaining({ jobId: "unsubscribe-unsubscribe-1" }),
    );
  });

  it("restores provider failures without automatically replaying them", async () => {
    const failedJob = {
      ...queuedJob,
      status: JobStatus.FAILED,
      completedAt: new Date("2026-07-25T10:00:00.000Z"),
      metadata: { error: "Unsubscribe endpoint returned status 503." },
    };
    const prisma = {
      mockDataEnabled: false,
      unsubscribeJob: {
        findMany: jest.fn().mockResolvedValue([failedJob]),
      },
    };
    const queue = {
      getJob: jest.fn(),
      add: jest.fn(),
    };
    const service = new UnsubscribeService(prisma as never, queue as never);

    await expect(service.getActiveJobs("user-1")).resolves.toEqual({
      items: [
        expect.objectContaining({
          id: "unsubscribe-1",
          status: JobStatus.FAILED,
          failureReason:
            "The sender rejected or could not complete the one-click request.",
          metadata: undefined,
        }),
      ],
    });
    expect(queue.getJob).not.toHaveBeenCalled();
    expect(queue.add).not.toHaveBeenCalled();
  });
});
