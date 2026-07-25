import { IdempotencyService } from "./idempotency.service";
import { PrismaService } from "../../database/prisma.service";

describe("IdempotencyService", () => {
  const key = "0123456789abcdefghij";

  function setup(existing: Record<string, unknown> | null = null) {
    const prisma = {
      idempotencyRecord: {
        findUnique: jest.fn().mockResolvedValue(existing),
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
        create: jest.fn().mockResolvedValue({ id: "record-1" }),
        update: jest.fn().mockResolvedValue({ id: "record-1" }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    } as unknown as PrismaService;
    return { service: new IdempotencyService(prisma), prisma };
  }

  it("executes an operation once and persists its replay response", async () => {
    const { service, prisma } = setup();
    const operation = jest.fn().mockResolvedValue({ success: true });

    await expect(
      service.execute("user-1", "messages.trash", key, "hash-1", operation),
    ).resolves.toEqual({ success: true });

    expect(operation).toHaveBeenCalledTimes(1);
    expect(prisma.idempotencyRecord.create).toHaveBeenCalledTimes(1);
    expect(prisma.idempotencyRecord.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { status: "COMPLETED", response: { success: true } },
      }),
    );
  });

  it("returns a completed response without running the operation again", async () => {
    const { service } = setup({
      id: "record-1",
      requestHash: "hash-1",
      status: "COMPLETED",
      response: { success: true },
      expiresAt: new Date(Date.now() + 60_000),
    });
    const operation = jest.fn();

    await expect(
      service.execute("user-1", "messages.trash", key, "hash-1", operation),
    ).resolves.toEqual({ success: true });
    expect(operation).not.toHaveBeenCalled();
  });

  it("rejects reuse of a key for a different request", async () => {
    const { service } = setup({
      id: "record-1",
      requestHash: "hash-1",
      status: "COMPLETED",
      response: { success: true },
      expiresAt: new Date(Date.now() + 60_000),
    });

    await expect(
      service.execute("user-1", "messages.trash", key, "hash-2", jest.fn()),
    ).rejects.toThrow("different request");
  });
});
