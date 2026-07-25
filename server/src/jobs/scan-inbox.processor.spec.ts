import { ScanInboxProcessor } from "./scan-inbox.processor";

describe("ScanInboxProcessor provider routing", () => {
  it.each([
    ["GOOGLE", "gmail"],
    ["YAHOO", "yahoo"],
  ] as const)(
    "routes %s accounts to the %s sync adapter",
    async (provider, expected) => {
      const prisma = {
        emailAccount: {
          findUniqueOrThrow: jest.fn().mockResolvedValue({ provider }),
        },
      };
      const gmail = {
        syncAccount: jest.fn().mockResolvedValue({ processed: 1 }),
      };
      const yahoo = {
        syncAccount: jest.fn().mockResolvedValue({ processed: 1 }),
      };
      const processor = new ScanInboxProcessor(
        prisma as never,
        gmail as never,
        yahoo as never,
      );
      const updateProgress = jest.fn();

      await processor.process({
        id: "job-1",
        data: { emailAccountId: "account-1" },
        attemptsMade: 0,
        opts: { attempts: 1 },
        updateProgress,
      });

      expect(gmail.syncAccount).toHaveBeenCalledTimes(
        expected === "gmail" ? 1 : 0,
      );
      expect(yahoo.syncAccount).toHaveBeenCalledTimes(
        expected === "yahoo" ? 1 : 0,
      );
    },
  );

  it("does not route unsupported providers through Gmail or Yahoo", async () => {
    const prisma = {
      emailAccount: {
        findUniqueOrThrow: jest
          .fn()
          .mockResolvedValue({ provider: "MICROSOFT" }),
      },
    };
    const gmail = { syncAccount: jest.fn() };
    const yahoo = { syncAccount: jest.fn() };
    const processor = new ScanInboxProcessor(
      prisma as never,
      gmail as never,
      yahoo as never,
    );

    await expect(
      processor.process({
        id: "job-1",
        data: { emailAccountId: "account-1" },
        attemptsMade: 0,
        opts: { attempts: 1 },
        updateProgress: jest.fn(),
      }),
    ).rejects.toThrow("MICROSOFT");
    expect(gmail.syncAccount).not.toHaveBeenCalled();
    expect(yahoo.syncAccount).not.toHaveBeenCalled();
  });
});
