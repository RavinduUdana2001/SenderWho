import "reflect-metadata";
import { SenderControl, SenderKind } from "./dto/list-senders.dto";
import { SendersService } from "./senders.service";

describe("SendersService ownership", () => {
  function setup() {
    const prisma = {
      mockDataEnabled: false,
      sender: {
        findFirst: jest.fn().mockResolvedValue(null),
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(0),
        update: jest.fn(),
      },
      auditLog: { create: jest.fn() },
    };
    return { prisma, service: new SendersService(prisma as never) };
  }

  it("scopes list and count queries to the authenticated user", async () => {
    const { prisma, service } = setup();

    await service.list("owner-user", {
      page: 1,
      limit: 25,
      skip: 0,
      kind: SenderKind.ALL,
      control: SenderControl.ALL,
    });

    expect(prisma.sender.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ userId: "owner-user" }),
      }),
    );
    expect(prisma.sender.count).toHaveBeenCalledWith({
      where: expect.objectContaining({ userId: "owner-user" }),
    });
  });

  it("rejects foreign sender reads and controls before mutation", async () => {
    const { prisma, service } = setup();

    await expect(
      service.getById("owner-user", "foreign-sender"),
    ).rejects.toThrow("not found");
    await expect(
      service.setBlocked("owner-user", "foreign-sender", true),
    ).rejects.toThrow("not found");
    await expect(
      service.setTrusted("owner-user", "foreign-sender", true),
    ).rejects.toThrow("not found");

    for (const call of prisma.sender.findFirst.mock.calls) {
      expect(call[0]).toEqual(
        expect.objectContaining({
          where: { id: "foreign-sender", userId: "owner-user" },
        }),
      );
    }
    expect(prisma.sender.update).not.toHaveBeenCalled();
    expect(prisma.auditLog.create).not.toHaveBeenCalled();
  });

  it("keeps a persisted sender control successful when audit storage fails", async () => {
    const { prisma, service } = setup();
    prisma.sender.findFirst.mockResolvedValue({ id: "sender-1" });
    prisma.sender.update.mockResolvedValue({
      id: "sender-1",
      isBlocked: true,
      isTrusted: false,
    });
    prisma.auditLog.create.mockRejectedValue(new Error("audit unavailable"));

    await expect(
      service.setBlocked("owner-user", "sender-1", true),
    ).resolves.toMatchObject({ isBlocked: true, isTrusted: false });
    expect(prisma.sender.update).toHaveBeenCalledTimes(1);
  });
});
