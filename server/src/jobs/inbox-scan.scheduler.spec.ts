import { InboxScanScheduler } from "./inbox-scan.scheduler";
import { PrismaService } from "../database/prisma.service";
import { InboxJobsService } from "./inbox-jobs.service";

describe("InboxScanScheduler", () => {
  it("does not automatically requeue accounts whose last scan failed", async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const scheduler = new InboxScanScheduler(
      { emailAccount: { findMany } } as unknown as PrismaService,
      { enqueueScan: jest.fn() } as unknown as InboxJobsService,
    );

    await (
      scheduler as unknown as { enqueueDueAccounts(): Promise<void> }
    ).enqueueDueAccounts();

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { syncStatus: { in: ["PENDING", "PARTIAL", "READY"] } },
      }),
    );
  });
});
