import { SearchService } from "./search.service";

describe("SearchService", () => {
  function setup() {
    const prisma = {
      sender: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: "sender-26",
            name: "Billing",
            email: "billing@example.test",
            category: "FINANCE",
            trustScore: 82,
          },
        ]),
        count: jest.fn().mockResolvedValue(30),
      },
      message: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: "message-26",
            subject: "Invoice",
            receivedAt: new Date("2026-07-20T08:00:00.000Z"),
            isRead: false,
            hasAttachments: true,
            sender: { name: "Billing", email: "billing@example.test" },
          },
        ]),
        count: jest.fn().mockResolvedValue(40),
      },
    };
    return { prisma, service: new SearchService(prisma as never) };
  }

  it("scopes every sender and message search to the authenticated user", async () => {
    const { prisma, service } = setup();

    const result = await service.search("owner-user", {
      query: "invoice",
      selected: ["Finance", "High (75+)"],
      hasAttachments: true,
      unreadOnly: true,
      page: 2,
      limit: 25,
    });

    expect(prisma.sender.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ userId: "owner-user" }),
        skip: 25,
        take: 25,
      }),
    );
    expect(prisma.message.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          userId: "owner-user",
          isRead: false,
          isTrashed: false,
          hasAttachments: true,
        }),
        skip: 25,
        take: 25,
      }),
    );
    expect(prisma.sender.count).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ userId: "owner-user" }),
      }),
    );
    expect(prisma.message.count).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ userId: "owner-user" }),
      }),
    );
    expect(result).toMatchObject({
      total: 70,
      page: 2,
      limit: 25,
      hasMore: true,
      returned: 2,
    });
  });

  it("reports the final page when both scoped result sets are exhausted", async () => {
    const { prisma, service } = setup();
    prisma.sender.count.mockResolvedValue(1);
    prisma.message.count.mockResolvedValue(1);

    const result = await service.search("owner-user", {
      page: 1,
      limit: 25,
    });

    expect(result.hasMore).toBe(false);
  });
});

describe("message-constrained sender search", () => {
  it.each([
    { unreadOnly: true, hasAttachments: false },
    { unreadOnly: false, hasAttachments: true },
    { unreadOnly: true, hasAttachments: true },
  ])("requires a matching sender message for %j", async (flags) => {
    const senderFind = jest.fn().mockResolvedValue([]);
    const messageFind = jest.fn().mockResolvedValue([]);
    const service = new SearchService({
      sender: { findMany: senderFind, count: jest.fn().mockResolvedValue(0) },
      message: { findMany: messageFind, count: jest.fn().mockResolvedValue(0) },
    } as never);
    await service.search("owner", {
      ...flags,
      selected: ["Finance", "This Month"],
      query: "invoice",
      page: 1,
      limit: 25,
    });
    const messageWhere = messageFind.mock.calls[0][0].where;
    expect(senderFind.mock.calls[0][0].where.messages).toEqual({
      some: messageWhere,
    });
    expect(messageWhere).toMatchObject({
      userId: "owner",
      isTrashed: false,
      category: { in: ["FINANCE"] },
      receivedAt: { gte: expect.any(Date) },
    });
    if (flags.unreadOnly) expect(messageWhere.isRead).toBe(false);
    if (flags.hasAttachments) expect(messageWhere.hasAttachments).toBe(true);
  });
});
