import {
  Injectable,
  Logger,
  NotFoundException,
  UnprocessableEntityException,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { PrismaService } from "../database/prisma.service";
import {
  GmailApiError,
  GmailClient,
  GmailMessage,
} from "../providers/gmail/gmail.client";
import { GmailSyncService } from "../providers/gmail/gmail-sync.service";
import { GoogleTokenService } from "../providers/google-token.service";
import { YahooSyncService } from "../providers/yahoo/yahoo-sync.service";
import { ListMessagesDto, MessageMailbox } from "./dto/list-messages.dto";

type MessageAction =
  "archive" | "unarchive" | "trash" | "restore" | "mark_read" | "mark_unread";

interface StoredMessage {
  id: string;
  emailAccountId: string;
  providerMessageId: string;
}

@Injectable()
export class EmailMessagesService {
  private readonly logger = new Logger(EmailMessagesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly gmail: GmailClient,
    private readonly googleTokens: GoogleTokenService,
    private readonly gmailSync: GmailSyncService,
    private readonly yahooSync?: YahooSyncService,
  ) {}

  async list(userId: string, query: ListMessagesDto) {
    const where = this.messageWhere(userId, query);
    const [messages, total] = await Promise.all([
      this.prisma.message.findMany({
        where,
        include: {
          sender: true,
          emailAccount: { select: { emailAddress: true } },
        },
        orderBy: [{ receivedAt: "desc" }, { id: "desc" }],
        skip: query.skip,
        take: query.limit,
      }),
      this.prisma.message.count({ where }),
    ]);

    return {
      items: messages.map((message) => this.toMessageItem(message)),
      total,
      page: query.page,
      limit: query.limit,
      hasMore: query.skip + messages.length < total,
    };
  }

  async getById(userId: string, id: string) {
    const message = await this.prisma.message.findFirst({
      where: { id, userId },
      include: {
        sender: true,
        emailAccount: { select: { emailAddress: true } },
      },
    });
    if (!message) throw new NotFoundException("Gmail message was not found.");
    return this.toMessageItem(message);
  }

  async getThread(userId: string, id: string) {
    const anchor = await this.prisma.message.findFirst({
      where: { id, userId },
      select: { id: true, emailAccountId: true, threadId: true },
    });
    if (!anchor) throw new NotFoundException("Gmail message was not found.");

    const messages = await this.prisma.message.findMany({
      where: anchor.threadId
        ? {
            userId,
            emailAccountId: anchor.emailAccountId,
            threadId: anchor.threadId,
          }
        : { userId, id: anchor.id },
      include: {
        sender: true,
        emailAccount: { select: { emailAddress: true } },
      },
      orderBy: [{ receivedAt: "asc" }, { id: "asc" }],
    });

    return {
      threadId: anchor.threadId,
      total: messages.length,
      items: messages.map((message) => this.toMessageItem(message)),
    };
  }

  async getContent(userId: string, id: string) {
    const stored = await this.prisma.message.findFirst({
      where: { id, userId },
      select: {
        id: true,
        emailAccountId: true,
        providerMessageId: true,
        emailAccount: { select: { provider: true } },
      },
    });
    if (!stored) throw new NotFoundException("Email message was not found.");
    if (stored.emailAccount.provider === "YAHOO") {
      if (!this.yahooSync) {
        throw new NotFoundException("Yahoo message content is unavailable.");
      }
      const content = await this.yahooSync.getMessageContent(
        stored.emailAccountId,
        stored.providerMessageId,
      );
      return { id: stored.id, ...content };
    }
    if (stored.emailAccount.provider !== "GOOGLE") {
      throw new UnprocessableEntityException(
        `Mailbox provider ${stored.emailAccount.provider} is not supported.`,
      );
    }

    let accessToken = await this.googleTokens.getAccessToken(
      stored.emailAccountId,
    );
    let message: GmailMessage;
    try {
      message = await this.gmail.getMessageContent(
        accessToken,
        stored.providerMessageId,
      );
    } catch (error) {
      if (!(error instanceof GmailApiError) || error.status !== 401)
        throw error;
      accessToken = await this.googleTokens.getAccessToken(
        stored.emailAccountId,
        true,
      );
      message = await this.gmail.getMessageContent(
        accessToken,
        stored.providerMessageId,
      );
    }

    return this.toMessageContent(stored.id, message);
  }

  async getPromotionEmails(userId: string) {
    const messages = await this.prisma.message.findMany({
      where: {
        userId,
        isTrashed: false,
        category: { in: ["PROMOTIONS", "NEWSLETTERS"] },
      },
      include: {
        sender: true,
        emailAccount: { select: { emailAddress: true } },
      },
      orderBy: { receivedAt: "desc" },
      take: 100,
    });
    return { items: messages.map((message) => this.toMessageItem(message)) };
  }

  archive(userId: string, messageIds: string[]) {
    return this.applyAction(userId, messageIds, "archive");
  }

  unarchive(userId: string, messageIds: string[]) {
    return this.applyAction(userId, messageIds, "unarchive");
  }

  trash(userId: string, messageIds: string[]) {
    return this.applyAction(userId, messageIds, "trash");
  }

  restore(userId: string, messageIds: string[]) {
    return this.applyAction(userId, messageIds, "restore");
  }

  setReadState(userId: string, messageIds: string[], isRead: boolean) {
    return this.applyAction(
      userId,
      messageIds,
      isRead ? "mark_read" : "mark_unread",
    );
  }

  private async applyAction(
    userId: string,
    messageIds: string[],
    action: MessageAction,
  ) {
    const uniqueMessageIds = [...new Set(messageIds)];
    const messages = await this.prisma.message.findMany({
      where: { userId, id: { in: uniqueMessageIds } },
      select: { id: true, emailAccountId: true, providerMessageId: true },
    });
    if (messages.length !== uniqueMessageIds.length) {
      throw new NotFoundException("One or more email messages were not found.");
    }

    const byAccount = new Map<string, StoredMessage[]>();
    for (const message of messages) {
      const accountMessages = byAccount.get(message.emailAccountId) ?? [];
      accountMessages.push(message);
      byAccount.set(message.emailAccountId, accountMessages);
    }

    const processedIds: string[] = [];
    const failures: Array<{ messageId: string; reason: string }> = [];
    for (const [emailAccountId, accountMessages] of byAccount) {
      const result = await this.applyAccountAction(
        emailAccountId,
        accountMessages,
        action,
      );
      processedIds.push(...result.processedIds);
      failures.push(...result.failures);
      if (result.processedIds.length > 0) {
        await this.persistAction(userId, result.processedIds, action);
        await this.safeSideEffect(
          "gmail.message.recalculate.failed",
          emailAccountId,
          () => this.gmailSync.recalculateAccount(emailAccountId),
        );
        await this.safeSideEffect(
          "gmail.message.cleanup_refresh.failed",
          emailAccountId,
          () => this.gmailSync.refreshCleanupSuggestions(emailAccountId),
        );
      }
    }

    await this.safeSideEffect(
      "gmail.message.audit.failed",
      userId,
      async () => {
        await this.prisma.auditLog.create({
          data: {
            userId,
            action: `gmail.message.${action}`,
            targetType: "Message",
            metadata: {
              requested: uniqueMessageIds.length,
              processed: processedIds.length,
              failed: failures.length,
            },
          },
        });
      },
    );

    return {
      action,
      requested: uniqueMessageIds.length,
      processed: processedIds.length,
      failed: failures.length,
      processedIds,
      failures,
    };
  }

  private async safeSideEffect(
    event: string,
    targetId: string,
    operation: () => Promise<unknown>,
  ) {
    try {
      await operation();
    } catch (error) {
      this.logger.error(
        JSON.stringify({
          event,
          targetId,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
    }
  }

  private async applyAccountAction(
    emailAccountId: string,
    messages: StoredMessage[],
    action: MessageAction,
  ) {
    const account = await this.prisma.emailAccount.findUniqueOrThrow({
      where: { id: emailAccountId },
      select: { provider: true },
    });
    if (account.provider === "YAHOO") {
      return this.applyYahooAccountAction(emailAccountId, messages, action);
    }
    if (account.provider !== "GOOGLE") {
      return {
        processedIds: [] as string[],
        failures: messages.map((message) => ({
          messageId: message.id,
          reason: `Mailbox provider ${account.provider} is not supported.`,
        })),
      };
    }
    let accessToken = await this.googleTokens.getAccessToken(emailAccountId);
    const refreshToken = async () => {
      accessToken = await this.googleTokens.getAccessToken(
        emailAccountId,
        true,
      );
    };

    if (action !== "trash" && action !== "restore") {
      try {
        await this.modifyBatch(accessToken, messages, action);
      } catch (error) {
        if (!(error instanceof GmailApiError) || error.status !== 401) {
          return {
            processedIds: [] as string[],
            failures: messages.map((message) => ({
              messageId: message.id,
              reason: this.safeProviderError(error),
            })),
          };
        }
        try {
          await refreshToken();
          await this.modifyBatch(accessToken, messages, action);
        } catch (retryError) {
          return {
            processedIds: [] as string[],
            failures: messages.map((message) => ({
              messageId: message.id,
              reason: this.safeProviderError(retryError),
            })),
          };
        }
      }
      return {
        processedIds: messages.map((message) => message.id),
        failures: [] as Array<{ messageId: string; reason: string }>,
      };
    }

    const processedIds: string[] = [];
    const failures: Array<{ messageId: string; reason: string }> = [];
    await this.mapWithConcurrency(messages, 6, async (message) => {
      const providerAction = (token: string) =>
        action === "trash"
          ? this.gmail.trashMessage(token, message.providerMessageId)
          : this.gmail.untrashMessage(token, message.providerMessageId);
      try {
        await providerAction(accessToken);
        processedIds.push(message.id);
      } catch (error) {
        if (error instanceof GmailApiError && error.status === 401) {
          try {
            await refreshToken();
            await providerAction(accessToken);
            processedIds.push(message.id);
            return;
          } catch (retryError) {
            failures.push({
              messageId: message.id,
              reason: this.safeProviderError(retryError),
            });
            return;
          }
        }
        failures.push({
          messageId: message.id,
          reason: this.safeProviderError(error),
        });
      }
    });
    return { processedIds, failures };
  }

  private async applyYahooAccountAction(
    emailAccountId: string,
    messages: StoredMessage[],
    action: MessageAction,
  ) {
    if (!this.yahooSync) {
      return {
        processedIds: [] as string[],
        failures: messages.map((message) => ({
          messageId: message.id,
          reason: "Yahoo Mail actions are unavailable.",
        })),
      };
    }
    const processedIds: string[] = [];
    const failures: Array<{ messageId: string; reason: string }> = [];
    await this.mapWithConcurrency(messages, 2, async (message) => {
      try {
        const result = await this.yahooSync!.applyMessageAction(
          emailAccountId,
          message.providerMessageId,
          action,
        );
        if (result.providerMessageId !== message.providerMessageId) {
          await this.prisma.message.update({
            where: { id: message.id },
            data: { providerMessageId: result.providerMessageId },
          });
        }
        processedIds.push(message.id);
      } catch (error) {
        failures.push({
          messageId: message.id,
          reason: this.safeProviderError(error),
        });
      }
    });
    return { processedIds, failures };
  }

  private modifyBatch(
    accessToken: string,
    messages: StoredMessage[],
    action: Exclude<MessageAction, "trash" | "restore">,
  ) {
    const providerIds = messages.map((message) => message.providerMessageId);
    switch (action) {
      case "archive":
        return this.gmail.batchModifyMessages(accessToken, providerIds, {
          removeLabelIds: ["INBOX"],
        });
      case "unarchive":
        return this.gmail.batchModifyMessages(accessToken, providerIds, {
          addLabelIds: ["INBOX"],
        });
      case "mark_read":
        return this.gmail.batchModifyMessages(accessToken, providerIds, {
          removeLabelIds: ["UNREAD"],
        });
      case "mark_unread":
        return this.gmail.batchModifyMessages(accessToken, providerIds, {
          addLabelIds: ["UNREAD"],
        });
    }
  }

  private persistAction(
    userId: string,
    processedIds: string[],
    action: MessageAction,
  ) {
    const data: Prisma.MessageUpdateManyMutationInput = (() => {
      switch (action) {
        case "archive":
          return { isArchived: true };
        case "unarchive":
          return { isArchived: false, isTrashed: false };
        case "trash":
          return { isTrashed: true, isArchived: false };
        case "restore":
          return { isTrashed: false };
        case "mark_read":
          return { isRead: true };
        case "mark_unread":
          return { isRead: false };
      }
    })();
    return this.prisma.message.updateMany({
      where: { userId, id: { in: processedIds } },
      data,
    });
  }

  private messageWhere(
    userId: string,
    query: ListMessagesDto,
  ): Prisma.MessageWhereInput {
    const text = query.query?.trim();
    const mailbox: Prisma.MessageWhereInput = (() => {
      switch (query.mailbox) {
        case MessageMailbox.ALL:
          return { isTrashed: false };
        case MessageMailbox.UNREAD:
          return { isTrashed: false, isRead: false };
        case MessageMailbox.READ:
          return { isTrashed: false, isRead: true };
        case MessageMailbox.ARCHIVED:
          return { isTrashed: false, isArchived: true };
        case MessageMailbox.TRASH:
          return { isTrashed: true };
        case MessageMailbox.INBOX:
          return { isTrashed: false, isArchived: false };
      }
    })();
    return {
      userId,
      ...mailbox,
      ...(query.cleanupCategory
        ? {
            sender: { isTrusted: false },
            category: { not: "IMPORTANT" },
            ...this.cleanupWhere(query.cleanupCategory),
          }
        : {}),
      ...(query.category ? { category: query.category } : {}),
      ...(query.senderId ? { senderId: query.senderId } : {}),
      ...(query.hasAttachments !== undefined
        ? { hasAttachments: query.hasAttachments }
        : {}),
      ...(text
        ? {
            OR: [
              { subject: { contains: text } },
              { snippet: { contains: text } },
              { sender: { name: { contains: text } } },
              { sender: { email: { contains: text } } },
            ],
          }
        : {}),
    };
  }

  private cleanupWhere(category: string): Prisma.MessageWhereInput {
    switch (category) {
      case "MARKETING":
        return { category: "PROMOTIONS" };
      case "NEWSLETTERS":
        return { category: "NEWSLETTERS" };
      case "SPAM":
        return { category: "SPAM" };
      case "OLD_UNREAD":
        return {
          isRead: false,
          receivedAt: {
            lt: new Date(Date.now() - 90 * 24 * 60 * 60 * 1_000),
          },
        };
      case "LARGE_ATTACHMENTS":
        return { sizeBytes: { gte: 5 * 1_024 * 1_024 } };
      default:
        return {};
    }
  }

  private toMessageItem(message: {
    id: string;
    senderId: string | null;
    threadId: string | null;
    subject: string | null;
    snippet: string | null;
    receivedAt: Date;
    category: string;
    isRead: boolean;
    isArchived: boolean;
    isTrashed: boolean;
    hasAttachments: boolean;
    sizeBytes: number | null;
    listUnsubscribeUrl: string | null;
    listUnsubscribePost: boolean;
    identityRiskScore: number;
    identityRiskLevel: string;
    identityStatus: string;
    identityEvidence: Prisma.JsonValue | null;
    claimedBrand: string | null;
    authenticatedDomain: string | null;
    replyToEmail: string | null;
    sender: { name: string | null; email: string } | null;
    emailAccount: { emailAddress: string };
  }) {
    return {
      id: message.id,
      senderId: message.senderId,
      threadId: message.threadId,
      sender: message.sender?.name ?? message.sender?.email ?? "Unknown",
      email: message.sender?.email ?? "",
      subject: message.subject ?? "(No subject)",
      snippet: message.snippet ?? "",
      date: message.receivedAt.toISOString(),
      category: message.category,
      isRead: message.isRead,
      isArchived: message.isArchived,
      isTrashed: message.isTrashed,
      hasAttachments: message.hasAttachments,
      sizeBytes: message.sizeBytes,
      canUnsubscribe:
        message.listUnsubscribePost && Boolean(message.listUnsubscribeUrl),
      accountEmail: message.emailAccount.emailAddress,
      identityRiskScore: message.identityRiskScore,
      identityRiskLevel: message.identityRiskLevel,
      identityStatus: message.identityStatus,
      identityEvidence: message.identityEvidence ?? [],
      claimedBrand: message.claimedBrand,
      authenticatedDomain: message.authenticatedDomain,
      replyToEmail: message.replyToEmail,
    };
  }

  private safeProviderError(error: unknown) {
    if (error instanceof GmailApiError) {
      return `Gmail returned status ${error.status}.`;
    }
    return "The Gmail action could not be completed.";
  }

  private toMessageContent(id: string, message: GmailMessage) {
    const headers = new Map(
      (message.payload?.headers ?? []).map((header) => [
        header.name.toLowerCase(),
        header.value,
      ]),
    );
    const bodies = { plain: [] as string[], html: [] as string[] };
    const attachments: Array<{ filename: string; sizeBytes: number }> = [];
    this.collectMessageParts(message.payload, bodies, attachments);
    const fullText = bodies.plain.join("\n\n").trim();
    const htmlText = bodies.html.join("\n\n").trim();
    const body = fullText || this.htmlToPlainText(htmlText);
    const maxLength = 500_000;

    return {
      id,
      from: headers.get("from") ?? "",
      to: headers.get("to") ?? "",
      cc: headers.get("cc") ?? "",
      subject: headers.get("subject") ?? "(No subject)",
      date: headers.get("date") ?? "",
      bodyText: body.slice(0, maxLength),
      truncated: body.length > maxLength,
      attachments,
    };
  }

  private collectMessageParts(
    payload: GmailMessage["payload"],
    bodies: { plain: string[]; html: string[] },
    attachments: Array<{ filename: string; sizeBytes: number }>,
  ) {
    if (!payload) return;
    const filename = payload.filename?.trim();
    if (filename) {
      attachments.push({
        filename,
        sizeBytes: payload.body?.size ?? 0,
      });
    }
    const encoded = payload.body?.data;
    if (encoded && !filename) {
      const decoded = this.decodeBase64Url(encoded);
      if (payload.mimeType === "text/plain") bodies.plain.push(decoded);
      if (payload.mimeType === "text/html") bodies.html.push(decoded);
    }
    for (const part of payload.parts ?? []) {
      this.collectMessageParts(part, bodies, attachments);
    }
  }

  private decodeBase64Url(value: string): string {
    try {
      return Buffer.from(value, "base64url").toString("utf8");
    } catch {
      return "";
    }
  }

  private htmlToPlainText(value: string): string {
    return value
      .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, " ")
      .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, " ")
      .replace(/<(br|\/p|\/div|\/li)>/gi, "\n")
      .replace(/<[^>]+>/g, " ")
      .replace(/&nbsp;/gi, " ")
      .replace(/&amp;/gi, "&")
      .replace(/&lt;/gi, "<")
      .replace(/&gt;/gi, ">")
      .replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, "'")
      .replace(/[ \t]+/g, " ")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
  }

  private async mapWithConcurrency<T>(
    values: T[],
    concurrency: number,
    action: (value: T) => Promise<void>,
  ) {
    let index = 0;
    const workers = Array.from(
      { length: Math.min(concurrency, values.length) },
      async () => {
        while (index < values.length) {
          const current = values[index];
          index += 1;
          await action(current);
        }
      },
    );
    await Promise.all(workers);
  }
}
