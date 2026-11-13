import { ConfigService } from "@nestjs/config";
import { GmailSyncService } from "./gmail-sync.service";
import { gmailApiError } from "./gmail.client";

function setup() {
  const prisma = {
    emailAccount: {
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      findUniqueOrThrow: jest.fn().mockResolvedValue({
        userId: "owner",
        historyId: null,
        metadataVersion: 3,
        backfillPageToken: null,
        backfillHistoryId: null,
        backfillComplete: false,
        backfillProcessed: 0,
      }),
      findUnique: jest.fn().mockResolvedValue({ userId: "owner" }),
      update: jest.fn().mockResolvedValue({}),
    },
    auditLog: { create: jest.fn().mockResolvedValue({}) },
  };
  const gmail = {
    getProfile: jest.fn().mockResolvedValue({
      emailAddress: "second@example.test",
      historyId: "history",
    }),
    listMessages: jest
      .fn()
      .mockResolvedValue({ messages: [{ id: "one", threadId: "thread" }] }),
    getMessagesBatch: jest.fn(),
  };
  const tokens = {
    getAccessToken: jest
      .fn()
      .mockResolvedValueOnce("old-token")
      .mockResolvedValue("fresh-token"),
  };
  const service = new GmailSyncService(
    new ConfigService(),
    prisma as never,
    gmail as never,
    tokens as never,
    {} as never,
  );
  jest
    .spyOn(service as never, "persistMessage")
    .mockResolvedValue(false as never);
  jest.spyOn(service, "recalculateAccount").mockResolvedValue(undefined);
  jest.spyOn(service, "refreshCleanupSuggestions").mockResolvedValue(undefined);
  jest
    .spyOn(service as never, "waitForQuota")
    .mockResolvedValue(undefined as never);
  return { service, prisma, gmail, tokens };
}

describe("Gmail mailbox scan recovery", () => {
  afterEach(() => jest.restoreAllMocks());

  it("persists successful items and recalculates counts even when the first item is rate limited", async () => {
    const { service, prisma, gmail } = setup();
    gmail.listMessages.mockResolvedValue({
      messages: [{ id: "one" }, { id: "two" }],
    });
    gmail.getMessagesBatch.mockResolvedValue([
      { id: "one", status: 429, retryAfterMs: 120_000 },
      { id: "two", status: 200, message: { id: "two", threadId: "thread" } },
    ]);
    await expect(service.syncAccount("second")).rejects.toMatchObject({
      retryAfterMs: 120_000,
    });
    expect(service["persistMessage"]).toHaveBeenCalledWith(
      "second",
      "owner",
      expect.objectContaining({ id: "two" }),
    );
    expect(service.recalculateAccount).toHaveBeenCalledWith("second");
    expect(prisma.emailAccount.update).not.toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ backfillComplete: true }),
      }),
    );
  });

  it("checkpoints complete pages and resumes after the last completed page", async () => {
    const { service, prisma, gmail } = setup();
    gmail.listMessages
      .mockResolvedValueOnce({
        messages: [{ id: "one" }],
        nextPageToken: "page-two",
      })
      .mockResolvedValueOnce({ messages: [{ id: "two" }] });
    gmail.getMessagesBatch
      .mockResolvedValueOnce([
        { id: "one", status: 200, message: { id: "one", threadId: "thread" } },
      ])
      .mockResolvedValueOnce([
        { id: "two", status: 403, errorReason: "userRateLimitExceeded" },
      ]);
    await expect(service.syncAccount("second")).rejects.toMatchObject({
      retryAfterMs: 60_000,
    });
    expect(prisma.emailAccount.update).toHaveBeenCalledWith({
      where: { id: "second" },
      data: {
        backfillPageToken: "page-two",
        backfillHistoryId: "history",
        backfillProcessed: 1,
      },
    });
    prisma.emailAccount.findUniqueOrThrow.mockResolvedValue({
      userId: "owner",
      historyId: null,
      metadataVersion: 3,
      backfillPageToken: "page-two",
      backfillHistoryId: "history",
      backfillComplete: false,
      backfillProcessed: 1,
    });
    gmail.listMessages.mockResolvedValue({ messages: [{ id: "two" }] });
    gmail.getMessagesBatch.mockResolvedValue([
      { id: "two", status: 200, message: { id: "two", threadId: "thread" } },
    ]);
    await expect(service.syncAccount("second")).resolves.toMatchObject({
      backfillProcessed: 2,
    });
    expect(gmail.listMessages).toHaveBeenLastCalledWith(
      "fresh-token",
      expect.objectContaining({ pageToken: "page-two" }),
    );
    expect(prisma.emailAccount.update).toHaveBeenLastCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          syncStatus: "READY",
          backfillComplete: true,
          historyId: "history",
        }),
      }),
    );
  });

  it("paces consecutive metadata pages instead of bursting the full mailbox", async () => {
    const { service, gmail } = setup();
    jest.spyOn(Date, "now").mockReturnValue(1_000_000);
    gmail.listMessages
      .mockResolvedValueOnce({
        messages: [{ id: "one" }],
        nextPageToken: "next",
      })
      .mockResolvedValueOnce({ messages: [{ id: "two" }] });
    gmail.getMessagesBatch
      .mockResolvedValueOnce([
        { id: "one", status: 200, message: { id: "one", threadId: "thread" } },
      ])
      .mockResolvedValueOnce([
        { id: "two", status: 200, message: { id: "two", threadId: "thread" } },
      ]);
    await service.syncAccount("second");
    expect(service["waitForQuota"]).toHaveBeenNthCalledWith(1, 0, undefined);
    expect(service["waitForQuota"]).toHaveBeenNthCalledWith(2, 300, undefined);
    expect(service.recalculateAccount).toHaveBeenCalledWith("second", ["one"]);
    expect(service.recalculateAccount).toHaveBeenCalledWith("second", ["two"]);
  });
  it("refreshes an expired batch token once and finishes importing the selected mailbox", async () => {
    const { service, prisma, gmail, tokens } = setup();
    gmail.getMessagesBatch
      .mockRejectedValueOnce(gmailApiError(401))
      .mockResolvedValueOnce([
        { id: "one", status: 200, message: { id: "one", threadId: "thread" } },
      ]);
    await expect(service.syncAccount("second")).resolves.toMatchObject({
      processed: 1,
    });
    expect(tokens.getAccessToken).toHaveBeenLastCalledWith("second", true);
    expect(gmail.getMessagesBatch).toHaveBeenLastCalledWith("fresh-token", [
      "one",
    ]);
    expect(prisma.emailAccount.update).toHaveBeenLastCalledWith(
      expect.objectContaining({
        where: { id: "second" },
        data: expect.objectContaining({ syncStatus: "READY" }),
      }),
    );
  });

  it("keeps a permission-failed mailbox selected and provides reconnect guidance", async () => {
    const { service, prisma, gmail } = setup();
    gmail.getMessagesBatch.mockResolvedValueOnce([
      { id: "one", status: 403, errorReason: "insufficientPermissions" },
    ]);
    await expect(service.syncAccount("second")).rejects.toMatchObject({
      status: 403,
    });
    expect(prisma.emailAccount.update).toHaveBeenCalledWith({
      where: { id: "second" },
      data: expect.objectContaining({
        syncStatus: "FAILED",
        lastSyncError: expect.stringContaining("Reconnect"),
      }),
    });
    for (const [args] of prisma.emailAccount.update.mock.calls) {
      expect(args.data).not.toHaveProperty("isPrimary");
    }
  });
});
