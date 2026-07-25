import { EmailMessagesService } from "./email-messages.service";
import { MessageMailbox } from "./dto/list-messages.dto";

describe("EmailMessagesService", () => {
  const message = {
    id: "message-1",
    senderId: "sender-1",
    emailAccountId: "account-1",
    providerMessageId: "gmail-1",
    threadId: "thread-1",
    subject: "Invoice available",
    snippet: "Your invoice is ready",
    receivedAt: new Date("2026-07-14T10:00:00.000Z"),
    category: "FINANCE",
    isRead: false,
    isArchived: false,
    isTrashed: false,
    hasAttachments: true,
    sizeBytes: 1024,
    listUnsubscribeUrl: null,
    listUnsubscribePost: false,
    sender: { name: "Billing", email: "billing@example.com" },
    emailAccount: { emailAddress: "person@example.com" },
  };

  function setup() {
    const prisma = {
      message: {
        findMany: jest.fn(),
        findFirst: jest.fn(),
        count: jest.fn(),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        update: jest.fn().mockResolvedValue({}),
      },
      emailAccount: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({ provider: "GOOGLE" }),
      },
      auditLog: { create: jest.fn().mockResolvedValue({ id: "audit-1" }) },
    };
    const gmail = {
      batchModifyMessages: jest.fn().mockResolvedValue(undefined),
      getMessageContent: jest.fn(),
      trashMessage: jest.fn(),
      untrashMessage: jest.fn(),
    };
    const tokens = {
      getAccessToken: jest.fn().mockResolvedValue("google-access"),
    };
    const gmailSync = {
      recalculateAccount: jest.fn().mockResolvedValue(undefined),
      refreshCleanupSuggestions: jest.fn().mockResolvedValue(undefined),
    };
    const service = new EmailMessagesService(
      prisma as never,
      gmail as never,
      tokens as never,
      gmailSync as never,
    );
    return { service, prisma, gmail, gmailSync };
  }

  it("returns paginated real message metadata with mailbox filters", async () => {
    const { service, prisma } = setup();
    prisma.message.findMany.mockResolvedValue([message]);
    prisma.message.count.mockResolvedValue(1);

    const result = await service.list("user-1", {
      page: 1,
      limit: 25,
      skip: 0,
      mailbox: MessageMailbox.UNREAD,
    });

    expect(prisma.message.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          userId: "user-1",
          isRead: false,
          isTrashed: false,
        }),
      }),
    );
    expect(result).toMatchObject({ total: 1, page: 1, hasMore: false });
    expect(result.items[0]).toMatchObject({
      id: "message-1",
      sender: "Billing",
      isRead: false,
      hasAttachments: true,
    });
  });

  it("marks Gmail messages read before committing the local state", async () => {
    const { service, prisma, gmail, gmailSync } = setup();
    prisma.message.findMany.mockResolvedValue([
      {
        id: message.id,
        emailAccountId: message.emailAccountId,
        providerMessageId: message.providerMessageId,
      },
    ]);

    const result = await service.setReadState("user-1", [message.id], true);

    expect(gmail.batchModifyMessages).toHaveBeenCalledWith(
      "google-access",
      ["gmail-1"],
      { removeLabelIds: ["UNREAD"] },
    );
    expect(prisma.message.updateMany).toHaveBeenCalledWith({
      where: { userId: "user-1", id: { in: ["message-1"] } },
      data: { isRead: true },
    });
    expect(gmailSync.recalculateAccount).toHaveBeenCalledWith("account-1");
    expect(result).toMatchObject({ requested: 1, processed: 1, failed: 0 });
  });

  it("does not report a failed Gmail mutation when derived-data or audit refreshes fail", async () => {
    const { service, prisma, gmail, gmailSync } = setup();
    prisma.message.findMany.mockResolvedValue([
      {
        id: message.id,
        emailAccountId: message.emailAccountId,
        providerMessageId: message.providerMessageId,
      },
    ]);
    gmailSync.recalculateAccount.mockRejectedValue(
      new Error("derived data unavailable"),
    );
    gmailSync.refreshCleanupSuggestions.mockRejectedValue(
      new Error("suggestions unavailable"),
    );
    prisma.auditLog.create.mockRejectedValue(new Error("audit unavailable"));

    await expect(
      service.archive("user-1", [message.id]),
    ).resolves.toMatchObject({
      processed: 1,
      failed: 0,
      processedIds: [message.id],
    });
    expect(gmail.batchModifyMessages).toHaveBeenCalledTimes(1);
    expect(prisma.message.updateMany).toHaveBeenCalledTimes(1);
  });

  it("rejects a mixed-ownership bulk action before calling Gmail", async () => {
    const { service, prisma, gmail } = setup();
    prisma.message.findMany.mockResolvedValue([
      {
        id: "message-1",
        emailAccountId: "account-1",
        providerMessageId: "gmail-1",
      },
    ]);

    await expect(
      service.trash("user-1", ["message-1", "other-user-message"]),
    ).rejects.toThrow("not found");
    expect(gmail.trashMessage).not.toHaveBeenCalled();
  });

  it("returns every stored message in the selected Gmail conversation", async () => {
    const { service, prisma } = setup();
    prisma.message.findFirst.mockResolvedValue({
      id: message.id,
      emailAccountId: message.emailAccountId,
      threadId: message.threadId,
    });
    prisma.message.findMany.mockResolvedValue([
      message,
      {
        ...message,
        id: "message-2",
        providerMessageId: "gmail-2",
        sender: { name: "Person", email: "person@example.com" },
        receivedAt: new Date("2026-07-14T11:00:00.000Z"),
      },
    ]);

    const result = await service.getThread("user-1", message.id);

    expect(prisma.message.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          userId: "user-1",
          emailAccountId: "account-1",
          threadId: "thread-1",
        },
        orderBy: [{ receivedAt: "asc" }, { id: "asc" }],
      }),
    );
    expect(result).toMatchObject({
      threadId: "thread-1",
      total: 2,
      items: [
        { id: "message-1", threadId: "thread-1", sender: "Billing" },
        { id: "message-2", threadId: "thread-1", sender: "Person" },
      ],
    });
  });

  it("loads a selected Gmail body on demand without storing it", async () => {
    const { service, prisma, gmail } = setup();
    prisma.message.findFirst.mockResolvedValue({
      id: message.id,
      emailAccountId: message.emailAccountId,
      providerMessageId: message.providerMessageId,
      emailAccount: { provider: "GOOGLE" },
    });
    gmail.getMessageContent.mockResolvedValue({
      id: "gmail-1",
      threadId: "thread-1",
      payload: {
        mimeType: "multipart/alternative",
        headers: [
          { name: "From", value: "Billing <billing@example.com>" },
          { name: "To", value: "person@example.com" },
          { name: "Subject", value: "Invoice available" },
        ],
        parts: [
          {
            mimeType: "text/plain",
            body: {
              data: Buffer.from("Your full invoice is ready.").toString(
                "base64url",
              ),
            },
          },
        ],
      },
    });

    const result = await service.getContent("user-1", message.id);

    expect(gmail.getMessageContent).toHaveBeenCalledWith(
      "google-access",
      "gmail-1",
    );
    expect(result).toMatchObject({
      id: "message-1",
      from: "Billing <billing@example.com>",
      to: "person@example.com",
      subject: "Invoice available",
      bodyText: "Your full invoice is ready.",
      truncated: false,
    });
    expect(prisma.message.updateMany).not.toHaveBeenCalled();
  });
});
