import { Injectable, Logger, UnauthorizedException } from "@nestjs/common";
import { domainToASCII } from "node:url";
import {
  CleanupCategory,
  IdentityRiskLevel,
  IdentityStatus,
  JobStatus,
  Prisma,
  RiskLevel,
  SenderCategory,
  SyncStatus,
} from "@prisma/client";
import { ConfigService } from "@nestjs/config";
import { PrismaService } from "../../database/prisma.service";
import { GoogleTokenService } from "../google-token.service";
import {
  GmailApiError,
  GmailClient,
  GmailHistoryList,
  GmailMessage,
} from "./gmail.client";
import { getGoogleAccountRecoveryAction } from "../google-account-recovery";
import {
  IdentityAssessment,
  SenderIdentityRiskService,
} from "./sender-identity-risk.service";

interface SyncProgress {
  (processed: number, discovered: number): Promise<void> | void;
}

interface ParsedSender {
  email: string;
  name?: string;
  domain: string;
}

type GmailRequest = <T>(
  action: (accessToken: string) => Promise<T>,
) => Promise<T>;

// Increment whenever newly collected Gmail headers or derived message metadata
// require existing messages to be fetched again. Gmail history only describes
// changes, so it cannot enrich previously stored messages by itself.
export const CURRENT_GMAIL_METADATA_VERSION = 3;

export function aggregateSenderClassification(
  categories: SenderCategory[],
  latestCategory?: SenderCategory,
  identityAssessments: Array<{
    score: number;
    level: IdentityRiskLevel;
    status: IdentityStatus;
  }> = [],
) {
  const highestIdentity = identityAssessments.reduce(
    (highest, current) => (current.score > highest.score ? current : highest),
    {
      score: 0,
      level: IdentityRiskLevel.LOW,
      status: IdentityStatus.UNVERIFIED,
    },
  );
  const hasSpam = categories.includes(SenderCategory.SPAM);
  const riskLevel =
    hasSpam || highestIdentity.level === IdentityRiskLevel.HIGH
      ? RiskLevel.HIGH
      : highestIdentity.level === IdentityRiskLevel.POSSIBLE_IMPERSONATION ||
          highestIdentity.level === IdentityRiskLevel.REVIEW
        ? RiskLevel.MEDIUM
        : RiskLevel.LOW;
  const identityStatus =
    highestIdentity.score >= 50
      ? IdentityStatus.SUSPICIOUS
      : identityAssessments.some(
            (assessment) => assessment.status === IdentityStatus.VERIFIED,
          )
        ? IdentityStatus.VERIFIED
        : IdentityStatus.UNVERIFIED;
  return {
    category: latestCategory ?? SenderCategory.UNKNOWN,
    riskLevel,
    trustScore: Math.max(
      0,
      Math.min(
        100,
        (identityStatus === IdentityStatus.VERIFIED ? 100 : 70) -
          highestIdentity.score -
          (hasSpam ? 20 : 0),
      ),
    ),
    identityRiskScore: highestIdentity.score,
    identityRiskLevel: highestIdentity.level,
    identityStatus,
  };
}

export function isImportantOrStarred(labels: string[]) {
  return labels.includes("IMPORTANT") || labels.includes("STARRED");
}

export function extractSecureUnsubscribeUrl(value?: string) {
  if (!value) return undefined;
  const candidates = [...value.matchAll(/<([^>]+)>/g)].map((match) =>
    match[1].trim(),
  );
  for (const candidate of candidates) {
    try {
      const url = new URL(candidate);
      if (
        url.protocol === "https:" &&
        !url.username &&
        !url.password &&
        (!url.port || url.port === "443")
      ) {
        return url.toString();
      }
    } catch {
      // Ignore malformed alternatives and continue to the next header value.
    }
  }
  return undefined;
}

@Injectable()
export class GmailSyncService {
  private readonly logger = new Logger(GmailSyncService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly gmail: GmailClient,
    private readonly googleTokens: GoogleTokenService,
    private readonly identityRisk: SenderIdentityRiskService,
  ) {}

  persistProviderMessage(
    emailAccountId: string,
    userId: string,
    message: GmailMessage,
  ) {
    return this.persistMessage(emailAccountId, userId, message);
  }

  async syncAccount(emailAccountId: string, onProgress?: SyncProgress) {
    // Keep metadata batches deliberately below Gmail's hard limit of 50.
    // Each messages.get consumes quota independently even inside a batch, so
    // smaller bursts are substantially less likely to be rate limited.
    const maxMessages = Math.min(
      500,
      Math.max(25, this.config.get<number>("gmailSync.maxMessages", 500)),
    );
    const batchSize = Math.min(
      25,
      Math.max(5, this.config.get<number>("gmailSync.batchSize", 20)),
    );
    const concurrency = Math.min(
      8,
      Math.max(1, this.config.get<number>("gmailSync.concurrency", 5)),
    );

    const claimed = await this.prisma.emailAccount.updateMany({
      where: {
        id: emailAccountId,
        syncStatus: { not: SyncStatus.DISCONNECTED },
      },
      data: {
        syncStatus: SyncStatus.SYNCING,
        syncStartedAt: new Date(),
        lastSyncError: null,
      },
    });
    if (claimed.count !== 1) {
      throw new UnauthorizedException(
        "Reconnect this Gmail account before synchronizing.",
      );
    }

    try {
      const account = await this.prisma.emailAccount.findUniqueOrThrow({
        where: { id: emailAccountId },
        select: {
          userId: true,
          historyId: true,
          metadataVersion: true,
          backfillPageToken: true,
          backfillHistoryId: true,
          backfillComplete: true,
          backfillProcessed: true,
        },
      });
      const token = {
        value: await this.googleTokens.getAccessToken(emailAccountId),
      };
      const gmailRequest = async <T>(
        action: (accessToken: string) => Promise<T>,
      ): Promise<T> => {
        try {
          return await action(token.value);
        } catch (error) {
          if (!(error instanceof GmailApiError) || error.status !== 401) {
            throw error;
          }
          token.value = await this.googleTokens.getAccessToken(
            emailAccountId,
            true,
          );
          return action(token.value);
        }
      };
      const profile = await gmailRequest((accessToken) =>
        this.gmail.getProfile(accessToken),
      );
      let backfillPageToken = account.backfillPageToken;
      let backfillHistoryId = account.backfillHistoryId;
      let backfillProcessed = account.backfillProcessed;
      let syncResult:
        | {
            processed: number;
            discovered: number;
            historyId?: string;
            nextPageToken?: string;
          }
        | undefined;
      let fullBackfill = !account.backfillComplete;
      if (
        !fullBackfill &&
        account.historyId &&
        account.metadataVersion >= CURRENT_GMAIL_METADATA_VERSION
      ) {
        try {
          syncResult = await this.syncHistory(
            emailAccountId,
            account.userId,
            account.historyId,
            concurrency,
            gmailRequest,
            onProgress,
          );
        } catch (error) {
          if (!(error instanceof GmailApiError) || error.status !== 404) {
            throw error;
          }
          this.logger.warn(
            `Gmail history expired for ${emailAccountId}; running a full reconciliation.`,
          );
          fullBackfill = true;
          backfillPageToken = null;
          backfillHistoryId = profile.historyId ?? null;
          backfillProcessed = 0;
          await this.prisma.emailAccount.update({
            where: { id: emailAccountId },
            data: {
              backfillPageToken: null,
              backfillHistoryId: profile.historyId,
              backfillComplete: false,
              backfillProcessed: 0,
            },
          });
        }
      }
      if (!syncResult) {
        fullBackfill = true;
        syncResult = await this.syncFull(
          emailAccountId,
          account.userId,
          maxMessages,
          batchSize,
          concurrency,
          gmailRequest,
          onProgress,
          backfillPageToken ?? undefined,
        );
      }
      const { processed, discovered } = syncResult;

      await this.recalculateAccount(emailAccountId);
      await this.refreshCleanupSuggestions(emailAccountId);
      const needsContinuation = Boolean(syncResult.nextPageToken);
      const nextBackfillProcessed = fullBackfill
        ? backfillProcessed + processed
        : backfillProcessed;
      await this.prisma.emailAccount.update({
        where: { id: emailAccountId },
        data: {
          syncStatus: needsContinuation ? SyncStatus.PARTIAL : SyncStatus.READY,
          historyId: needsContinuation
            ? account.historyId
            : (syncResult.historyId ?? backfillHistoryId ?? profile.historyId),
          backfillPageToken: syncResult.nextPageToken ?? null,
          backfillHistoryId: needsContinuation
            ? (backfillHistoryId ?? profile.historyId)
            : null,
          backfillComplete: !needsContinuation,
          backfillProcessed: nextBackfillProcessed,
          lastSyncedAt: new Date(),
          syncStartedAt: null,
          lastSyncError: null,
          metadataVersion: CURRENT_GMAIL_METADATA_VERSION,
        },
      });
      await this.safeAudit(
        account.userId,
        needsContinuation ? "gmail.sync.partial" : "gmail.sync.completed",
        emailAccountId,
        { processed, discovered, backfillProcessed: nextBackfillProcessed },
      );

      return {
        processed,
        discovered,
        capped: needsContinuation,
        needsContinuation,
        backfillProcessed: nextBackfillProcessed,
      };
    } catch (error) {
      const message = this.safeErrorMessage(error);
      const recoveryAction = getGoogleAccountRecoveryAction(
        SyncStatus.FAILED,
        message,
      );
      const disconnected =
        error instanceof UnauthorizedException ||
        recoveryAction === "RECONNECT";
      await this.prisma.emailAccount.update({
        where: { id: emailAccountId },
        data: {
          syncStatus: disconnected
            ? SyncStatus.DISCONNECTED
            : SyncStatus.FAILED,
          syncStartedAt: null,
          lastSyncError: message,
        },
      });
      const account = await this.prisma.emailAccount.findUnique({
        where: { id: emailAccountId },
        select: { userId: true },
      });
      if (account) {
        await this.safeAudit(
          account.userId,
          "gmail.sync.failed",
          emailAccountId,
          { securityEvent: disconnected },
        );
      }
      this.logger.error(
        JSON.stringify({
          event: "gmail.sync.failed",
          targetId: emailAccountId,
          disconnected,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
          recoveryAction,
          reason: message,
        }),
      );
      throw error;
    }
  }

  private async syncFull(
    emailAccountId: string,
    userId: string,
    maxMessages: number,
    batchSize: number,
    concurrency: number,
    gmailRequest: GmailRequest,
    onProgress?: SyncProgress,
    initialPageToken?: string,
  ) {
    let pageToken = initialPageToken;
    let continuationToken: string | undefined;
    let processed = 0;
    let discovered = 0;
    do {
      const page = await gmailRequest((accessToken) =>
        this.gmail.listMessages(accessToken, {
          maxResults: Math.min(batchSize, maxMessages - discovered),
          pageToken,
          includeSpamTrash: true,
        }),
      );
      const messageRefs = page.messages ?? [];
      discovered += messageRefs.length;
      const batch = await gmailRequest((accessToken) =>
        this.gmail.getMessagesBatch(
          accessToken,
          messageRefs.map((ref) => ref.id),
        ),
      );
      await this.mapWithConcurrency(batch, concurrency, async (result) => {
        if (result.status === 404) {
          await this.prisma.message.deleteMany({
            where: {
              emailAccountId,
              providerMessageId: result.id,
            },
          });
        } else if (!result.message) {
          throw new GmailApiError(
            result.status,
            `Gmail batch item failed with status ${result.status}.`,
          );
        } else {
          const blocked = await this.persistMessage(
            emailAccountId,
            userId,
            result.message,
          );
          if (blocked && !(result.message.labelIds ?? []).includes("TRASH")) {
            await gmailRequest((accessToken) =>
              this.gmail.trashMessage(accessToken, result.id),
            );
            await this.prisma.message.updateMany({
              where: { emailAccountId, providerMessageId: result.id },
              data: { isTrashed: true, isArchived: false },
            });
          }
          processed += 1;
        }
        if (processed % 25 === 0 || processed === discovered) {
          await onProgress?.(processed, discovered);
        }
      });
      continuationToken = page.nextPageToken;
      pageToken = discovered < maxMessages ? continuationToken : undefined;
    } while (pageToken);
    return {
      processed,
      discovered,
      nextPageToken: continuationToken,
    };
  }

  private async syncHistory(
    emailAccountId: string,
    userId: string,
    startHistoryId: string,
    concurrency: number,
    gmailRequest: GmailRequest,
    onProgress?: SyncProgress,
  ) {
    let pageToken: string | undefined;
    let historyId: string | undefined;
    const changedIds = new Set<string>();
    const deletedIds = new Set<string>();
    do {
      const page: GmailHistoryList = await gmailRequest((accessToken) =>
        this.gmail.listHistory(accessToken, startHistoryId, pageToken),
      );
      historyId = page.historyId ?? historyId;
      for (const history of page.history ?? []) {
        for (const message of history.messages ?? [])
          changedIds.add(message.id);
        for (const item of history.messagesAdded ?? []) {
          changedIds.add(item.message.id);
        }
        for (const item of history.labelsAdded ?? []) {
          changedIds.add(item.message.id);
        }
        for (const item of history.labelsRemoved ?? []) {
          changedIds.add(item.message.id);
        }
        for (const item of history.messagesDeleted ?? []) {
          deletedIds.add(item.message.id);
          changedIds.delete(item.message.id);
        }
      }
      pageToken = page.nextPageToken;
    } while (pageToken);

    if (deletedIds.size > 0) {
      await this.prisma.message.deleteMany({
        where: {
          emailAccountId,
          providerMessageId: { in: [...deletedIds] },
        },
      });
    }

    const ids = [...changedIds];
    let processed = 0;
    await this.mapWithConcurrency(ids, concurrency, async (id) => {
      const persisted = await this.fetchAndPersistMessage(
        emailAccountId,
        userId,
        id,
        gmailRequest,
      );
      if (persisted) processed += 1;
      if (processed % 25 === 0 || processed === ids.length) {
        await onProgress?.(processed, ids.length + deletedIds.size);
      }
    });
    return {
      processed,
      discovered: ids.length + deletedIds.size,
      historyId,
    };
  }

  private async fetchAndPersistMessage(
    emailAccountId: string,
    userId: string,
    providerMessageId: string,
    gmailRequest: GmailRequest,
  ) {
    let message: GmailMessage;
    try {
      message = await gmailRequest((accessToken) =>
        this.gmail.getMessage(accessToken, providerMessageId),
      );
    } catch (error) {
      if (error instanceof GmailApiError && error.status === 404) {
        await this.prisma.message.deleteMany({
          where: { emailAccountId, providerMessageId },
        });
        return false;
      }
      throw error;
    }
    const blocked = await this.persistMessage(emailAccountId, userId, message);
    if (blocked && !(message.labelIds ?? []).includes("TRASH")) {
      await gmailRequest((accessToken) =>
        this.gmail.trashMessage(accessToken, providerMessageId),
      );
      await this.prisma.message.updateMany({
        where: { emailAccountId, providerMessageId },
        data: { isTrashed: true, isArchived: false },
      });
    }
    return true;
  }

  async recalculateAccount(emailAccountId: string) {
    const senders = await this.prisma.sender.findMany({
      where: { emailAccountId },
      select: { id: true },
    });

    await this.mapWithConcurrency(senders, 12, async ({ id }) => {
      const [summary, unreadMessages, latestMessage, messages] =
        await Promise.all([
          this.prisma.message.aggregate({
            where: { senderId: id, isTrashed: false },
            _count: { _all: true },
            _min: { receivedAt: true },
            _max: { receivedAt: true },
          }),
          this.prisma.message.count({
            where: { senderId: id, isRead: false, isTrashed: false },
          }),
          this.prisma.message.findFirst({
            where: { senderId: id, isTrashed: false },
            orderBy: [{ receivedAt: "desc" }, { id: "desc" }],
            select: { category: true },
          }),
          this.prisma.message.findMany({
            where: { senderId: id, isTrashed: false },
            select: {
              category: true,
              identityRiskScore: true,
              identityRiskLevel: true,
              identityStatus: true,
            },
          }),
        ]);
      const classification = aggregateSenderClassification(
        messages.map((message) => message.category),
        latestMessage?.category,
        messages.map((message) => ({
          score: message.identityRiskScore,
          level: message.identityRiskLevel,
          status: message.identityStatus,
        })),
      );

      await this.prisma.sender.update({
        where: { id },
        data: {
          totalMessages: summary._count._all,
          unreadMessages,
          firstSeenAt: summary._min.receivedAt,
          lastSeenAt: summary._max.receivedAt,
          ...classification,
        },
      });
    });
  }

  async refreshCleanupSuggestions(emailAccountId: string) {
    const definitions: Array<{
      category: CleanupCategory;
      where: Record<string, unknown>;
    }> = [
      {
        category: CleanupCategory.MARKETING,
        where: { category: SenderCategory.PROMOTIONS },
      },
      {
        category: CleanupCategory.NEWSLETTERS,
        where: { category: SenderCategory.NEWSLETTERS },
      },
      {
        category: CleanupCategory.SPAM,
        where: { category: SenderCategory.SPAM },
      },
      {
        category: CleanupCategory.OLD_UNREAD,
        where: {
          isRead: false,
          receivedAt: {
            lt: new Date(Date.now() - 90 * 24 * 60 * 60 * 1_000),
          },
        },
      },
      {
        category: CleanupCategory.LARGE_ATTACHMENTS,
        where: { sizeBytes: { gte: 5 * 1_024 * 1_024 } },
      },
    ];

    await this.prisma.cleanupSuggestion.deleteMany({
      where: { emailAccountId },
    });
    const account = await this.prisma.emailAccount.findUniqueOrThrow({
      where: { id: emailAccountId },
      select: { userId: true },
    });

    for (const definition of definitions) {
      const summary = await this.prisma.message.aggregate({
        where: {
          emailAccountId,
          isTrashed: false,
          isImportant: false,
          category: { not: SenderCategory.IMPORTANT },
          sender: { isTrusted: false },
          ...definition.where,
        },
        _count: { _all: true },
        _sum: { sizeBytes: true },
      });
      if (summary._count._all === 0) continue;

      await this.prisma.cleanupSuggestion.upsert({
        where: {
          emailAccountId_category: {
            emailAccountId,
            category: definition.category,
          },
        },
        create: {
          userId: account.userId,
          emailAccountId,
          category: definition.category,
          messageCount: summary._count._all,
          estimatedSpaceBytes: summary._sum.sizeBytes ?? 0,
          status: JobStatus.QUEUED,
        },
        update: {
          messageCount: summary._count._all,
          estimatedSpaceBytes: summary._sum.sizeBytes ?? 0,
          status: JobStatus.QUEUED,
        },
      });
    }
  }

  private async persistMessage(
    emailAccountId: string,
    userId: string,
    message: GmailMessage,
  ) {
    const headers = this.collectHeaders(message.payload?.headers ?? []);
    const header = (name: string) => headers.get(name)?.[0];
    const sender = this.parseSender(header("from"), message.id);
    const labels = message.labelIds ?? [];
    const category = this.inferCategory(labels, header("subject"));
    const assessment = this.identityRisk.assess({
      displayName: sender.name,
      fromEmail: sender.email,
      labels,
      headers,
    });
    const unsubscribeUrl = extractSecureUnsubscribeUrl(
      header("list-unsubscribe"),
    );
    const receivedAt = this.parseReceivedAt(
      message.internalDate,
      header("date"),
    );

    const senderWhere = {
      emailAccountId_email: { emailAccountId, email: sender.email },
    };
    const senderUpdate = { name: sender.name };
    let senderRecord: { id: string; isBlocked: boolean; isTrusted: boolean };
    try {
      senderRecord = await this.prisma.sender.upsert({
        where: senderWhere,
        create: {
          userId,
          emailAccountId,
          name: sender.name,
          email: sender.email,
          domain: sender.domain,
          category,
        },
        update: senderUpdate,
        select: { id: true, isBlocked: true, isTrusted: true },
      });
    } catch (error) {
      if (!this.isUniqueConstraintError(error)) throw error;
      senderRecord = await this.prisma.sender.update({
        where: senderWhere,
        data: senderUpdate,
        select: { id: true, isBlocked: true, isTrusted: true },
      });
    }

    const messageWhere = {
      emailAccountId_providerMessageId: {
        emailAccountId,
        providerMessageId: message.id,
      },
    };
    const messageUpdate = {
      senderId: senderRecord.id,
      threadId: message.threadId,
      subject: header("subject") ?? "(No subject)",
      snippet: message.snippet?.trim() || null,
      receivedAt,
      category,
      isRead: !labels.includes("UNREAD"),
      labels,
      isImportant: isImportantOrStarred(labels),
      riskFlags: assessment.evidence.map((item) => item.code),
      identityRiskScore: assessment.score,
      identityRiskLevel: assessment.level,
      identityStatus: assessment.status,
      identityEvidence: assessment.evidence as unknown as Prisma.InputJsonValue,
      claimedBrand: assessment.claimedBrand,
      authenticatedDomain: assessment.authenticatedDomain,
      replyToEmail: assessment.replyToEmail,
      sizeBytes: message.sizeEstimate,
      hasAttachments: this.hasAttachment(message.payload),
      listUnsubscribeUrl: unsubscribeUrl,
      listUnsubscribePost:
        header("list-unsubscribe-post")
          ?.toLowerCase()
          .includes("list-unsubscribe=one-click") ?? false,
      isArchived: !labels.includes("INBOX") && !labels.includes("TRASH"),
      isTrashed: labels.includes("TRASH"),
    };
    try {
      const storedMessage = await this.prisma.message.upsert({
        where: messageWhere,
        create: {
          userId,
          emailAccountId,
          providerMessageId: message.id,
          ...messageUpdate,
        },
        update: messageUpdate,
        select: { id: true },
      });
      await this.upsertSecurityAlert({
        userId,
        emailAccountId,
        senderId: senderRecord.id,
        messageId: storedMessage.id,
        assessment,
      });
    } catch (error) {
      if (!this.isUniqueConstraintError(error)) throw error;
      const storedMessage = await this.prisma.message.update({
        where: messageWhere,
        data: messageUpdate,
        select: { id: true },
      });
      await this.upsertSecurityAlert({
        userId,
        emailAccountId,
        senderId: senderRecord.id,
        messageId: storedMessage.id,
        assessment,
      });
    }
    return senderRecord.isBlocked;
  }

  private async upsertSecurityAlert(input: {
    userId: string;
    emailAccountId: string;
    senderId: string;
    messageId: string;
    assessment: IdentityAssessment;
  }) {
    if (input.assessment.score < 50) {
      await this.prisma.securityAlert.updateMany({
        where: { messageId: input.messageId, status: "OPEN" },
        data: { status: "RESOLVED", resolvedAt: new Date() },
      });
      return;
    }
    const highRisk = input.assessment.level === IdentityRiskLevel.HIGH;
    const reason = input.assessment.evidence
      .slice(0, 3)
      .map((item) => item.detail)
      .join(" ");
    await this.prisma.securityAlert.upsert({
      where: { messageId: input.messageId },
      create: {
        userId: input.userId,
        emailAccountId: input.emailAccountId,
        senderId: input.senderId,
        messageId: input.messageId,
        title: highRisk
          ? "High-risk identity warning"
          : "Possible sender impersonation",
        reason,
        riskLevel: highRisk ? RiskLevel.HIGH : RiskLevel.MEDIUM,
      },
      update: {
        senderId: input.senderId,
        riskLevel: highRisk ? RiskLevel.HIGH : RiskLevel.MEDIUM,
        title: highRisk
          ? "High-risk identity warning"
          : "Possible sender impersonation",
        reason,
      },
    });
  }

  private isUniqueConstraintError(error: unknown): boolean {
    return (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === "P2002"
    );
  }

  private collectHeaders(values: Array<{ name: string; value: string }>) {
    const headers = new Map<string, string[]>();
    for (const item of values) {
      const name = item.name.trim().toLowerCase();
      if (!name || typeof item.value !== "string") continue;
      headers.set(name, [...(headers.get(name) ?? []), item.value]);
    }
    return headers;
  }

  private parseSender(
    value: string | undefined,
    messageId: string,
  ): ParsedSender {
    const source = value?.trim() ?? "";
    const angleMatch = source.match(/^(.*?)<([^>]+)>$/);
    const emailCandidate = (angleMatch?.[2] ?? source)
      .trim()
      .replace(/^mailto:/i, "")
      .toLowerCase();
    const emailMatch = emailCandidate.match(/[^\s<>@]+@[^\s<>@]+/u);
    const [localPart, rawDomain] = (emailMatch?.[0] ?? "").split("@");
    const asciiDomain = domainToASCII(rawDomain ?? "").toLowerCase();
    const email =
      localPart && asciiDomain
        ? `${localPart.toLowerCase()}@${asciiDomain}`
        : `unknown-${messageId}@invalid.local`;
    const rawName = angleMatch?.[1]?.trim().replace(/^"|"$/g, "");

    return {
      email,
      name: rawName || undefined,
      domain: email.split("@")[1] ?? "invalid.local",
    };
  }

  private hasAttachment(payload: GmailMessage["payload"]): boolean {
    if (!payload) return false;
    if (payload.filename?.trim() || payload.body?.attachmentId) return true;
    return payload.parts?.some((part) => this.hasAttachment(part)) ?? false;
  }

  private inferCategory(labels: string[], subject?: string): SenderCategory {
    if (labels.includes("SPAM")) return SenderCategory.SPAM;
    if (labels.includes("CATEGORY_PROMOTIONS")) {
      return SenderCategory.PROMOTIONS;
    }
    if (labels.includes("CATEGORY_SOCIAL")) return SenderCategory.SOCIAL;
    if (labels.includes("CATEGORY_PERSONAL")) return SenderCategory.PEOPLE;
    if (labels.includes("IMPORTANT")) return SenderCategory.IMPORTANT;

    const normalizedSubject = subject?.toLowerCase() ?? "";
    if (/newsletter|digest|weekly update/.test(normalizedSubject)) {
      return SenderCategory.NEWSLETTERS;
    }
    if (/invoice|receipt|payment|bank|statement/.test(normalizedSubject)) {
      return SenderCategory.FINANCE;
    }
    if (/order|shipped|delivery|purchase/.test(normalizedSubject)) {
      return SenderCategory.ORDERS;
    }
    if (/flight|hotel|booking|reservation|travel/.test(normalizedSubject)) {
      return SenderCategory.TRAVEL;
    }
    return SenderCategory.UNKNOWN;
  }

  private parseReceivedAt(internalDate?: string, dateHeader?: string): Date {
    const internalTimestamp = Number(internalDate);
    if (Number.isFinite(internalTimestamp) && internalTimestamp > 0) {
      return new Date(internalTimestamp);
    }
    const headerTimestamp = dateHeader ? Date.parse(dateHeader) : Number.NaN;
    return Number.isFinite(headerTimestamp)
      ? new Date(headerTimestamp)
      : new Date();
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

  private async safeAudit(
    userId: string,
    action: string,
    emailAccountId: string,
    metadata: Record<string, number | boolean>,
  ) {
    try {
      await this.prisma.auditLog.create({
        data: {
          userId,
          action,
          targetType: "EmailAccount",
          targetId: emailAccountId,
          metadata,
        },
      });
    } catch (error) {
      this.logger.error(
        JSON.stringify({
          event: "gmail.sync.audit_failed",
          targetId: emailAccountId,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
    }
  }

  private safeErrorMessage(error: unknown): string {
    if (error instanceof Error) return error.message.slice(0, 1_000);
    return "Unknown Gmail synchronization error.";
  }
}
