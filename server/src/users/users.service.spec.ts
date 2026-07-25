import { UsersService } from "./users.service";

describe("UsersService privacy operations", () => {
  it("exports only the authenticated user's paginated records", async () => {
    const prisma = {
      auditLog: { create: jest.fn().mockResolvedValue({ id: "audit-1" }) },
      message: {
        findMany: jest.fn().mockResolvedValue([{ id: "message-51" }]),
      },
    };
    const service = new UsersService(prisma as never, {} as never);

    const result = await service.exportData("owner-user", {
      section: "messages",
      page: 2,
      limit: 50,
    });

    expect(prisma.message.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { userId: "owner-user" },
        skip: 50,
        take: 50,
      }),
    );
    expect(result).toMatchObject({
      section: "messages",
      page: 2,
      limit: 50,
      items: [{ id: "message-51" }],
      hasMore: false,
    });
  });

  it("deletes user audit data together with the account", async () => {
    const prisma = {
      user: {
        findFirst: jest.fn().mockResolvedValue({
          id: "user-1",
          emailAccounts: [],
        }),
        delete: jest.fn().mockReturnValue(Promise.resolve({ id: "user-1" })),
      },
      auditLog: {
        deleteMany: jest.fn().mockReturnValue(Promise.resolve({ count: 4 })),
      },
      emailAccount: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      cleanupJob: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      unsubscribeJob: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      appSession: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      $transaction: jest.fn().mockResolvedValue([{ count: 0 }]),
    };
    const service = new UsersService(prisma as never, {} as never);

    await expect(service.deleteAccount("user-1")).resolves.toMatchObject({
      success: true,
      providerRevocationsAttempted: 0,
    });
    expect(prisma.auditLog.deleteMany).toHaveBeenCalledWith({
      where: { userId: "user-1" },
    });
    expect(prisma.user.delete).toHaveBeenCalledWith({
      where: { id: "user-1" },
    });
  });
});
