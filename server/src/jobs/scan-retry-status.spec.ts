import { queuedScanRetries, scanJobId } from "./scan-retry-status";
import { EmailAccountsService } from "../email-accounts/email-accounts.service";

describe("Scheduled mailbox retry status", () => {
  it("queries only owned account job IDs and never exposes another mailbox", async () => {
    const availableAt = new Date(Date.now() + 120_000);
    const findMany = jest
      .fn()
      .mockResolvedValue([{ id: scanJobId("owned"), availableAt }]);
    const prisma = { backgroundJob: { findMany } };
    const result = await queuedScanRetries(prisma as never, ["owned"]);
    expect(findMany).toHaveBeenCalledWith({
      where: {
        id: { in: [scanJobId("owned")] },
        queue: "scan-inbox",
        status: "QUEUED",
      },
      select: { id: true, availableAt: true },
    });
    expect(result.get(scanJobId("owned"))).toEqual(availableAt);
    expect(result.has(scanJobId("other"))).toBe(false);
  });

  it("does not let Scan now reset a queued provider cooldown", async () => {
    const availableAt = new Date(Date.now() + 120_000);
    const prisma = {
      emailAccount: {
        findFirst: jest.fn().mockResolvedValue({
          id: "second",
          provider: "GOOGLE",
          syncStatus: "FAILED",
        }),
        update: jest.fn(),
      },
      backgroundJob: {
        findMany: jest
          .fn()
          .mockResolvedValue([{ id: scanJobId("second"), availableAt }]),
      },
    };
    const enqueueScan = jest.fn();
    const service = new EmailAccountsService(
      prisma as never,
      { enqueueScan } as never,
      {} as never,
    );
    await expect(service.queueSync("owner", "second")).resolves.toMatchObject({
      status: "QUEUED",
      syncRetryAt: availableAt,
    });
    expect(prisma.emailAccount.findFirst).toHaveBeenCalledWith({
      where: { id: "second", userId: "owner" },
      select: { id: true, provider: true, syncStatus: true },
    });
    expect(prisma.emailAccount.update).not.toHaveBeenCalled();
    expect(enqueueScan).not.toHaveBeenCalled();
  });
});
