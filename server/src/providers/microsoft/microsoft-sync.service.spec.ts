import { ConfigService } from "@nestjs/config";
import { MicrosoftSyncService } from "./microsoft-sync.service";

describe("MicrosoftSyncService", () => {
  it("persists Graph delta metadata and stores the durable delta cursor", async () => {
    const prisma = {
      emailAccount: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          userId: "user-1",
          providerSyncState: null,
          backfillProcessed: 0,
          backfillComplete: false,
        }),
        update: jest.fn().mockResolvedValue({}),
      },
      message: {
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };
    const graph = {
      listMailFolders: jest.fn().mockResolvedValue([
        {
          id: "inbox-folder",
          displayName: "Inbox",
          childFolderCount: 0,
        },
      ]),
      getFolderKinds: jest.fn().mockResolvedValue({ "inbox-folder": "inbox" }),
      listMessageDelta: jest.fn().mockResolvedValue({
        messages: [
          {
            id: "immutable-message-1",
            threadId: "conversation-1",
            labelIds: ["INBOX", "UNREAD"],
          },
        ],
        removedMessageIds: ["hard-deleted-message"],
        discovered: 2,
        deltaLink:
          "https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messages/delta?$deltatoken=next",
      }),
    };
    const tokens = {
      getAccessToken: jest.fn().mockResolvedValue("oauth-access-token"),
    };
    const metadata = {
      persistProviderMessage: jest.fn().mockResolvedValue(false),
      recalculateAccount: jest.fn().mockResolvedValue(undefined),
      refreshCleanupSuggestions: jest.fn().mockResolvedValue(undefined),
    };
    const service = new MicrosoftSyncService(
      new ConfigService({ gmailSync: { maxMessages: 500 } }),
      prisma as never,
      graph as never,
      tokens as never,
      metadata as never,
    );

    await expect(service.syncAccount("account-1")).resolves.toMatchObject({
      processed: 1,
      discovered: 2,
      needsContinuation: false,
      backfillProcessed: 1,
    });
    expect(graph.listMessageDelta).toHaveBeenCalledWith(
      "oauth-access-token",
      "inbox-folder",
      { "inbox-folder": "inbox" },
      undefined,
    );
    expect(metadata.persistProviderMessage).toHaveBeenCalledWith(
      "account-1",
      "user-1",
      expect.objectContaining({ id: "immutable-message-1" }),
    );
    expect(prisma.message.deleteMany).toHaveBeenCalledWith({
      where: {
        emailAccountId: "account-1",
        providerMessageId: { in: ["hard-deleted-message"] },
      },
    });
    expect(prisma.emailAccount.update).toHaveBeenCalledWith({
      where: { id: "account-1" },
      data: expect.objectContaining({
        syncStatus: "READY",
        backfillComplete: true,
        providerSyncState: expect.objectContaining({
          version: 1,
          cursorIndex: 0,
          folders: [
            expect.objectContaining({
              id: "inbox-folder",
              delta: expect.stringContaining("$deltatoken=next"),
            }),
          ],
        }),
      }),
    });
  });
});
