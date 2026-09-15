import { Injectable, Logger, UnauthorizedException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { EmailProvider, Prisma, SyncStatus } from "@prisma/client";
import { PrismaService } from "../../database/prisma.service";
import { GmailSyncService } from "../gmail/gmail-sync.service";
import {
  MicrosoftGraphClient,
  MicrosoftMessageAction,
} from "./microsoft-graph.client";
import { MicrosoftTokenService } from "./microsoft-token.service";

interface FolderSyncState {
  id: string;
  cursor?: string;
  delta?: string;
}

interface MicrosoftSyncState {
  version: 1;
  cursorIndex: number;
  folders: FolderSyncState[];
}

interface SyncProgress {
  (processed: number, discovered: number): Promise<void> | void;
}

@Injectable()
export class MicrosoftSyncService {
  private readonly logger = new Logger(MicrosoftSyncService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly graph: MicrosoftGraphClient,
    private readonly microsoftTokens: MicrosoftTokenService,
    private readonly metadata: GmailSyncService,
  ) {}

  async syncAccount(emailAccountId: string, onProgress?: SyncProgress) {
    const claimed = await this.prisma.emailAccount.updateMany({
      where: {
        id: emailAccountId,
        provider: EmailProvider.MICROSOFT,
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
        "Reconnect this Microsoft Outlook account before synchronizing.",
      );
    }

    try {
      const account = await this.prisma.emailAccount.findUniqueOrThrow({
        where: { id: emailAccountId },
        select: {
          userId: true,
          providerSyncState: true,
          backfillProcessed: true,
          backfillComplete: true,
        },
      });
      const maxMessages = Math.min(
        500,
        Math.max(25, this.config.get<number>("gmailSync.maxMessages", 500)),
      );
      const result = await this.withMicrosoftAccess(
        emailAccountId,
        async (accessToken) => {
          const [folders, folderKinds] = await Promise.all([
            this.graph.listMailFolders(accessToken),
            this.graph.getFolderKinds(accessToken),
          ]);
          const state = this.reconcileState(account.providerSyncState, folders);
          let processed = 0;
          let discovered = 0;
          let index = Math.min(
            state.cursorIndex,
            Math.max(0, state.folders.length - 1),
          );

          while (index < state.folders.length && processed < maxMessages) {
            const folder = state.folders[index];
            const page = await this.graph.listMessageDelta(
              accessToken,
              folder.id,
              folderKinds,
              folder.cursor ?? folder.delta,
            );
            discovered += page.discovered;
            if (page.removedMessageIds.length > 0) {
              await this.prisma.message.deleteMany({
                where: {
                  emailAccountId,
                  providerMessageId: { in: page.removedMessageIds },
                },
              });
            }
            for (const message of page.messages) {
              const blocked = await this.metadata.persistProviderMessage(
                emailAccountId,
                account.userId,
                message,
              );
              if (blocked && !(message.labelIds ?? []).includes("TRASH")) {
                await this.applyMessageAction(
                  emailAccountId,
                  message.id,
                  "trash",
                );
                await this.prisma.message.updateMany({
                  where: { emailAccountId, providerMessageId: message.id },
                  data: { isTrashed: true, isArchived: false },
                });
              }
              processed += 1;
            }
            await onProgress?.(processed, Math.max(discovered, processed));

            if (page.nextLink) {
              folder.cursor = page.nextLink;
              state.cursorIndex = index;
            } else {
              folder.cursor = undefined;
              if (page.deltaLink) folder.delta = page.deltaLink;
              index += 1;
              state.cursorIndex = index;
            }
          }
          const needsContinuation = index < state.folders.length;
          if (!needsContinuation) state.cursorIndex = 0;
          const backfillComplete = state.folders.every(
            (folder) => folder.delta,
          );
          return {
            state,
            processed,
            discovered,
            needsContinuation,
            backfillComplete,
          };
        },
      );

      await this.metadata.recalculateAccount(emailAccountId);
      await this.metadata.refreshCleanupSuggestions(emailAccountId);
      const backfillProcessed = account.backfillComplete
        ? account.backfillProcessed
        : account.backfillProcessed + result.processed;
      await this.prisma.emailAccount.update({
        where: { id: emailAccountId },
        data: {
          providerSyncState: result.state as unknown as Prisma.InputJsonValue,
          syncStatus: result.needsContinuation
            ? SyncStatus.PARTIAL
            : SyncStatus.READY,
          backfillComplete: result.backfillComplete,
          backfillProcessed,
          backfillPageToken: null,
          lastSyncedAt: new Date(),
          syncStartedAt: null,
          lastSyncError: null,
        },
      });
      return {
        processed: result.processed,
        discovered: result.discovered,
        needsContinuation: result.needsContinuation,
        capped: result.needsContinuation,
        backfillProcessed,
      };
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message.slice(0, 1_000)
          : "Unknown Microsoft Outlook synchronization error.";
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
          event: "microsoft.sync.failed",
          targetId: emailAccountId,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
      throw error;
    }
  }

  applyMessageAction(
    emailAccountId: string,
    providerMessageId: string,
    action: MicrosoftMessageAction,
  ) {
    return this.withMicrosoftAccess(emailAccountId, (accessToken) =>
      this.graph.applyMessageAction(accessToken, providerMessageId, action),
    );
  }

  getMessageContent(emailAccountId: string, providerMessageId: string) {
    return this.withMicrosoftAccess(emailAccountId, (accessToken) =>
      this.graph.getMessageContent(accessToken, providerMessageId),
    );
  }

  private reconcileState(
    value: Prisma.JsonValue | null,
    folders: Array<{ id: string }>,
  ): MicrosoftSyncState {
    const parsed = this.validState(value);
    const previous = new Map(
      (parsed?.folders ?? []).map((folder) => [folder.id, folder]),
    );
    return {
      version: 1,
      cursorIndex: parsed?.cursorIndex ?? 0,
      folders: folders.map((folder) => ({
        id: folder.id,
        cursor: previous.get(folder.id)?.cursor,
        delta: previous.get(folder.id)?.delta,
      })),
    };
  }

  private validState(
    value: Prisma.JsonValue | null,
  ): MicrosoftSyncState | null {
    if (!value || typeof value !== "object" || Array.isArray(value))
      return null;
    const candidate = value as Record<string, unknown>;
    if (candidate.version !== 1 || !Array.isArray(candidate.folders))
      return null;
    const folders = candidate.folders.flatMap((entry) => {
      if (!entry || typeof entry !== "object" || Array.isArray(entry))
        return [];
      const folder = entry as Record<string, unknown>;
      if (typeof folder.id !== "string") return [];
      return [
        {
          id: folder.id,
          cursor: typeof folder.cursor === "string" ? folder.cursor : undefined,
          delta: typeof folder.delta === "string" ? folder.delta : undefined,
        },
      ];
    });
    return {
      version: 1,
      cursorIndex:
        typeof candidate.cursorIndex === "number" &&
        Number.isInteger(candidate.cursorIndex) &&
        candidate.cursorIndex >= 0
          ? candidate.cursorIndex
          : 0,
      folders,
    };
  }

  private async withMicrosoftAccess<T>(
    emailAccountId: string,
    action: (accessToken: string) => Promise<T>,
  ) {
    try {
      return await action(
        await this.microsoftTokens.getAccessToken(emailAccountId),
      );
    } catch (error) {
      if (!(error instanceof UnauthorizedException)) throw error;
      return action(
        await this.microsoftTokens.getAccessToken(emailAccountId, true),
      );
    }
  }
}
