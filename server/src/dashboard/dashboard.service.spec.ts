import { DashboardService } from "./dashboard.service";

describe("DashboardService", () => {
  it("returns empty real metrics while the first Gmail scan is pending", async () => {
    const prisma = {
      mockDataEnabled: false,
      sender: {
        count: jest.fn().mockResolvedValue(0),
        findMany: jest.fn().mockResolvedValue([]),
      },
      message: {
        count: jest.fn().mockResolvedValue(0),
        aggregate: jest.fn().mockResolvedValue({
          _count: { _all: 0 },
          _sum: { sizeBytes: null },
        }),
      },
      securityAlert: {
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(0),
      },
      emailAccount: {
        findFirst: jest.fn().mockResolvedValue({
          id: "gmail-account",
          emailAddress: "person@example.com",
          syncStatus: "PENDING",
          lastSyncedAt: null,
          lastSyncError: null,
        }),
      },
    };
    const inboxHealth = {
      getHealth: jest.fn().mockResolvedValue({
        score: 0,
        status: "Waiting for scan",
        breakdown: [],
      }),
    };
    const service = new DashboardService(prisma as never, inboxHealth as never);

    await expect(
      service.getDashboardSummary("test-user"),
    ).resolves.toMatchObject({
      inboxHealth: { score: 0, status: "Waiting for scan" },
      metrics: {
        totalMessages: 0,
        totalSenders: 0,
        unreadEmails: 0,
        newsletters: 0,
        promotions: 0,
        spam: 0,
      },
      opportunities: {
        cleanupMessages: 0,
        estimatedSpaceBytes: 0,
        unsubscribeSenders: 0,
      },
      topSenders: [],
      recentAlerts: [],
      sync: { syncStatus: "PENDING" },
    });

    expect(prisma.message.aggregate).toHaveBeenCalledWith({
      where: {
        userId: "test-user",
        isTrashed: false,
        isImportant: false,
        category: { not: "IMPORTANT" },
        sender: { isTrusted: false },
        OR: [
          { category: "PROMOTIONS" },
          { category: "NEWSLETTERS" },
          { category: "SPAM" },
          {
            isRead: false,
            receivedAt: { lt: expect.any(Date) },
          },
          { sizeBytes: { gte: 5 * 1_024 * 1_024 } },
        ],
      },
      _count: { _all: true },
      _sum: { sizeBytes: true },
    });
    expect(inboxHealth.getHealth).toHaveBeenCalledWith("test-user");
  });

  it("uses the exact live score returned by the Inbox Health service", async () => {
    const prisma = {
      mockDataEnabled: false,
      sender: {
        count: jest.fn().mockResolvedValue(0),
        findMany: jest.fn().mockResolvedValue([]),
      },
      message: {
        count: jest.fn().mockResolvedValue(0),
        aggregate: jest.fn().mockResolvedValue({
          _count: { _all: 0 },
          _sum: { sizeBytes: null },
        }),
      },
      securityAlert: {
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(0),
      },
      emailAccount: {
        findFirst: jest.fn().mockResolvedValue(null),
      },
    };
    const inboxHealth = {
      getHealth: jest.fn().mockResolvedValue({
        score: 87,
        status: "Good",
        breakdown: [],
      }),
    };
    const service = new DashboardService(prisma as never, inboxHealth as never);

    await expect(
      service.getDashboardSummary("test-user"),
    ).resolves.toMatchObject({
      inboxHealth: { score: 87, status: "Good" },
    });
  });
});
