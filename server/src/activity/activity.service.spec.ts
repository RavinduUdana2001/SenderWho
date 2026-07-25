import { ActivityService } from "./activity.service";

describe("ActivityService", () => {
  it("reports only the current seven-day window and completed cleanup items", async () => {
    const prisma = {
      message: {
        count: jest.fn().mockResolvedValue(7),
        findMany: jest.fn().mockResolvedValue([]),
      },
      cleanupJobItem: {
        aggregate: jest.fn().mockResolvedValue({
          _count: { _all: 3 },
          _sum: { sizeBytes: 2_500_000 },
        }),
      },
    };
    const service = new ActivityService(prisma as never);

    const result = await service.getInsights("user-1");

    expect(result.period).toBe("Last 7 Days");
    expect(result.stats).toEqual([
      expect.objectContaining({ label: "Emails Received", value: "7" }),
      expect.objectContaining({ label: "Emails Cleaned", value: "3" }),
      expect.objectContaining({ label: "Cleanup Volume", value: "3 MB" }),
    ]);
    expect(prisma.message.count).toHaveBeenCalledWith({
      where: {
        userId: "user-1",
        receivedAt: { gte: expect.any(Date) },
      },
    });
    expect(prisma.cleanupJobItem.aggregate).toHaveBeenCalledWith({
      where: {
        status: "COMPLETED",
        processedAt: { gte: expect.any(Date) },
        cleanupJob: { userId: "user-1" },
      },
      _count: { _all: true },
      _sum: { sizeBytes: true },
    });
  });
});
