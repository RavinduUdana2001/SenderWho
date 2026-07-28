import { ConfigService } from "@nestjs/config";
import { YahooSyncService } from "./yahoo-sync.service";

describe("YahooSyncService", () => {
  it("imports a bounded IMAP page and persists its continuation cursor", async () => {
    const prisma = {
      emailAccount: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          userId: "user-1",
          emailAddress: "person@yahoo.com",
          backfillPageToken: null,
          backfillComplete: false,
          backfillProcessed: 0,
        }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    const yahooTokens = {
      getAccessToken: jest.fn().mockResolvedValue("oauth-access-token"),
    };
    const yahoo = {
      fetchInboxPage: jest.fn().mockResolvedValue({
        messages: [
          {
            id: "yahoo-inbox-50",
            threadId: "message-id",
            labelIds: ["INBOX", "UNREAD"],
          },
        ],
        discovered: 1,
        nextCursor: 50,
        highestUid: 75,
      }),
    };
    const metadata = {
      persistProviderMessage: jest.fn().mockResolvedValue(false),
      recalculateAccount: jest.fn().mockResolvedValue(undefined),
      refreshCleanupSuggestions: jest.fn().mockResolvedValue(undefined),
    };
    const service = new YahooSyncService(
      new ConfigService({ gmailSync: { maxMessages: 500 } }),
      prisma as never,
      yahoo as never,
      yahooTokens as never,
      metadata as never,
    );

    await expect(service.syncAccount("account-1")).resolves.toMatchObject({
      processed: 1,
      needsContinuation: true,
      backfillProcessed: 1,
    });
    expect(yahoo.fetchInboxPage).toHaveBeenCalledWith(
      "person@yahoo.com",
      "oauth-access-token",
      undefined,
      500,
    );
    expect(metadata.persistProviderMessage).toHaveBeenCalledWith(
      "account-1",
      "user-1",
      expect.objectContaining({ id: "yahoo-inbox-50" }),
    );
    expect(prisma.emailAccount.update).toHaveBeenCalledWith({
      where: { id: "account-1" },
      data: expect.objectContaining({
        syncStatus: "PARTIAL",
        historyId: "75",
        backfillPageToken: "50",
        backfillComplete: false,
      }),
    });
  });
});
