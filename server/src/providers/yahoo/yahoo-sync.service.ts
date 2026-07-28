import { Injectable, Logger, UnauthorizedException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { EmailProvider, SyncStatus } from "@prisma/client";
import { PrismaService } from "../../database/prisma.service";
import { GmailSyncService } from "../gmail/gmail-sync.service";
import { YahooImapClient } from "./yahoo-imap.client";
import { YahooMessageAction } from "./yahoo-imap.client";
import { YahooTokenService } from "./yahoo-token.service";

interface SyncProgress {
  (processed: number, discovered: number): Promise<void> | void;
}

@Injectable()
export class YahooSyncService {
  private readonly logger = new Logger(YahooSyncService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly yahoo: YahooImapClient,
    private readonly yahooTokens: YahooTokenService,
    private readonly metadata: GmailSyncService,
  ) {}

  async syncAccount(emailAccountId: string, onProgress?: SyncProgress) {
    const claimed = await this.prisma.emailAccount.updateMany({
      where: {
        id: emailAccountId,
        provider: EmailProvider.YAHOO,
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
        "Reconnect this Yahoo account before synchronizing.",
      );
    }

    try {
      const account = await this.prisma.emailAccount.findUniqueOrThrow({
        where: { id: emailAccountId },
        select: {
          userId: true,
          emailAddress: true,
          backfillPageToken: true,
          backfillComplete: true,
          backfillProcessed: true,
        },
      });
      const maxMessages = Math.min(
        500,
        Math.max(25, this.config.get<number>("gmailSync.maxMessages", 500)),
      );
      const cursor = account.backfillPageToken
        ? Math.max(1, Number.parseInt(account.backfillPageToken, 10) || 1)
        : undefined;
      const page = await this.withYahooAccess(emailAccountId, (accessToken) =>
        this.yahoo.fetchInboxPage(
          account.emailAddress,
          accessToken,
          cursor,
          maxMessages,
        ),
      );
      let processed = 0;
      for (const message of page.messages) {
        await this.metadata.persistProviderMessage(
          emailAccountId,
          account.userId,
          message,
        );
        processed += 1;
        if (processed % 25 === 0 || processed === page.discovered) {
          await onProgress?.(processed, page.discovered);
        }
      }
      await this.metadata.recalculateAccount(emailAccountId);
      await this.metadata.refreshCleanupSuggestions(emailAccountId);
      const needsContinuation = page.nextCursor != null;
      const backfillProcessed = account.backfillComplete
        ? account.backfillProcessed
        : account.backfillProcessed + processed;
      await this.prisma.emailAccount.update({
        where: { id: emailAccountId },
        data: {
          syncStatus: needsContinuation ? SyncStatus.PARTIAL : SyncStatus.READY,
          historyId: page.highestUid ? String(page.highestUid) : null,
          backfillPageToken: needsContinuation ? String(page.nextCursor) : null,
          backfillComplete: !needsContinuation,
          backfillProcessed,
          lastSyncedAt: new Date(),
          syncStartedAt: null,
          lastSyncError: null,
        },
      });
      return {
        processed,
        discovered: page.discovered,
        needsContinuation,
        capped: needsContinuation,
        backfillProcessed,
      };
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message.slice(0, 1_000)
          : "Unknown Yahoo synchronization error.";
      await this.prisma.emailAccount.update({
        where: { id: emailAccountId },
        data: {
          syncStatus:
            error instanceof UnauthorizedException
              ? SyncStatus.DISCONNECTED
              : SyncStatus.FAILED,
          syncStartedAt: null,
          lastSyncError: message,
        },
      });
      this.logger.error(
        JSON.stringify({
          event: "yahoo.sync.failed",
          targetId: emailAccountId,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
      throw error;
    }
  }

  async applyMessageAction(
    emailAccountId: string,
    providerMessageId: string,
    action: YahooMessageAction,
  ) {
    const account = await this.accountIdentity(emailAccountId);
    return this.withYahooAccess(emailAccountId, (accessToken) =>
      this.yahoo.applyMessageAction(
        account.emailAddress,
        accessToken,
        providerMessageId,
        action,
      ),
    );
  }

  async getMessageContent(emailAccountId: string, providerMessageId: string) {
    const account = await this.accountIdentity(emailAccountId);
    return this.withYahooAccess(emailAccountId, (accessToken) =>
      this.yahoo.getMessageContent(
        account.emailAddress,
        accessToken,
        providerMessageId,
      ),
    );
  }

  private async accountIdentity(emailAccountId: string) {
    const account = await this.prisma.emailAccount.findUniqueOrThrow({
      where: { id: emailAccountId },
      select: {
        provider: true,
        emailAddress: true,
      },
    });
    if (account.provider !== EmailProvider.YAHOO) {
      throw new UnauthorizedException(
        "Reconnect Yahoo Mail before continuing.",
      );
    }
    return { emailAddress: account.emailAddress };
  }

  private async withYahooAccess<T>(
    emailAccountId: string,
    action: (accessToken: string) => Promise<T>,
  ) {
    try {
      return await action(
        await this.yahooTokens.getAccessToken(emailAccountId),
      );
    } catch (error) {
      if (!(error instanceof UnauthorizedException)) throw error;
      return action(
        await this.yahooTokens.getAccessToken(emailAccountId, true),
      );
    }
  }
}
