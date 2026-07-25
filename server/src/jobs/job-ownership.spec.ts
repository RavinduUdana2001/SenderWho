import { CleanupService } from "../cleanup/cleanup.service";
import { UnsubscribeService } from "../unsubscribe/unsubscribe.service";
import { JobStatus } from "@prisma/client";

describe("Queued job ownership", () => {
  it("does not expose cleanup jobs belonging to another user", async () => {
    const prisma = {
      cleanupJob: { findFirst: jest.fn().mockResolvedValue(null) },
    };
    const service = new CleanupService(prisma as never, {} as never);

    await expect(service.getJob("owner-user", "foreign-job")).rejects.toThrow(
      "not found",
    );
    expect(prisma.cleanupJob.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: "foreign-job", userId: "owner-user" },
      }),
    );
  });

  it("does not expose unsubscribe jobs belonging to another user", async () => {
    const prisma = {
      mockDataEnabled: false,
      unsubscribeJob: { findFirst: jest.fn().mockResolvedValue(null) },
    };
    const service = new UnsubscribeService(prisma as never, {} as never);

    await expect(service.getJob("owner-user", "foreign-job")).rejects.toThrow(
      "not found",
    );
    expect(prisma.unsubscribeJob.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: "foreign-job", userId: "owner-user" },
      }),
    );
  });

  it("restores active and retryable unsubscribe jobs owned by the current user", async () => {
    const prisma = {
      mockDataEnabled: false,
      unsubscribeJob: { findMany: jest.fn().mockResolvedValue([]) },
    };
    const service = new UnsubscribeService(prisma as never, {} as never);

    await expect(service.getActiveJobs("owner-user")).resolves.toEqual({
      items: [],
    });
    expect(prisma.unsubscribeJob.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          userId: "owner-user",
          status: {
            in: [JobStatus.QUEUED, JobStatus.RUNNING, JobStatus.FAILED],
          },
        },
      }),
    );
  });
});
