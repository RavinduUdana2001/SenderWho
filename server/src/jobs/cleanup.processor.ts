import { CleanupCategory, JobStatus } from "@prisma/client";
import {
  Injectable,
  Logger,
  UnprocessableEntityException,
} from "@nestjs/common";
import { buildCleanupMessageWhere } from "../cleanup/cleanup.service";
import { PrismaService } from "../database/prisma.service";
import { GmailApiError, GmailClient } from "../providers/gmail/gmail.client";
import { GmailSyncService } from "../providers/gmail/gmail-sync.service";
import { GoogleTokenService } from "../providers/google-token.service";
import { YahooSyncService } from "../providers/yahoo/yahoo-sync.service";
import { ProcessorJob } from "./database-job-queue.service";

@Injectable()
export class CleanupProcessor {
  private readonly logger = new Logger(CleanupProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly gmail: GmailClient,
    private readonly googleTokens: GoogleTokenService,
    private readonly gmailSync: GmailSyncService,
    private readonly yahooSync?: YahooSyncService,
  ) {}

  async process(job: ProcessorJob<{ cleanupJobId: string }>) {
    const cleanupJob = await this.prisma.cleanupJob.findUniqueOrThrow({
      where: { id: job.data.cleanupJobId },
    });
    if (
      cleanupJob.status === JobStatus.COMPLETED ||
      cleanupJob.status === JobStatus.CANCELED
    ) {
      return {
        processedMessages: cleanupJob.processedMessages,
        failedMessages: cleanupJob.failedMessages,
        status: cleanupJob.status,
      };
    }
    const metadata = cleanupJob.metadata as { categories?: string[] } | null;
    const categories = (metadata?.categories ?? []) as CleanupCategory[];

    await this.prisma.cleanupJob.update({
      where: { id: cleanupJob.id },
      data: { status: JobStatus.RUNNING, startedAt: new Date() },
    });

    try {
      await this.prisma.cleanupJobItem.updateMany({
        where: { cleanupJobId: cleanupJob.id, status: "FAILED" },
        data: { status: "PENDING", errorCode: null, processedAt: null },
      });
      const items = await this.prisma.cleanupJobItem.findMany({
        where: { cleanupJobId: cleanupJob.id, status: "PENDING" },
        select: { id: true, messageId: true, providerMessageId: true },
      });
      const provider = this.yahooSync
        ? (
            await this.prisma.emailAccount.findUniqueOrThrow({
              where: { id: cleanupJob.emailAccountId },
              select: { provider: true },
            })
          ).provider
        : "GOOGLE";
      if (provider !== "GOOGLE" && provider !== "YAHOO") {
        throw new UnprocessableEntityException(
          `Mailbox provider ${provider} is not supported for cleanup.`,
        );
      }
      let accessToken =
        provider === "GOOGLE"
          ? await this.googleTokens.getAccessToken(cleanupJob.emailAccountId)
          : "";
      let completedSinceProgress = 0;

      await this.mapWithConcurrency(items, 6, async (item) => {
        const currentJob = await this.prisma.cleanupJob.findUnique({
          where: { id: cleanupJob.id },
          select: {
            status: true,
            emailAccount: { select: { syncStatus: true } },
          },
        });
        if (
          !currentJob ||
          currentJob.status === JobStatus.CANCELED ||
          currentJob.emailAccount.syncStatus === "DISCONNECTED"
        ) {
          await this.prisma.cleanupJobItem.update({
            where: { id: item.id },
            data: {
              status: "SKIPPED",
              errorCode: "JOB_CANCELED",
              processedAt: new Date(),
            },
          });
          return;
        }

        const message = item.messageId
          ? await this.prisma.message.findFirst({
              where: {
                ...buildCleanupMessageWhere(
                  cleanupJob.emailAccountId,
                  categories,
                ),
                id: item.messageId,
              },
              select: { id: true },
            })
          : null;
        if (!message) {
          await this.prisma.cleanupJobItem.update({
            where: { id: item.id },
            data: {
              status: "SKIPPED",
              errorCode: "NO_LONGER_ELIGIBLE",
              processedAt: new Date(),
            },
          });
          completedSinceProgress += 1;
          if (completedSinceProgress % 20 === 0) {
            await this.persistProgress(job, cleanupJob.id);
          }
          return;
        }

        try {
          const yahooResult =
            provider === "YAHOO"
              ? await this.yahooSync!.applyMessageAction(
                  cleanupJob.emailAccountId,
                  item.providerMessageId,
                  "trash",
                )
              : null;
          if (provider === "GOOGLE") {
            await this.gmail.trashMessage(accessToken, item.providerMessageId);
          }
          await this.prisma.message.update({
            where: { id: message.id },
            data: {
              isTrashed: true,
              isArchived: false,
              ...(yahooResult &&
              yahooResult.providerMessageId !== item.providerMessageId
                ? { providerMessageId: yahooResult.providerMessageId }
                : {}),
            },
          });
          await this.prisma.cleanupJobItem.update({
            where: { id: item.id },
            data: {
              status: "COMPLETED",
              errorCode: null,
              processedAt: new Date(),
            },
          });
        } catch (error) {
          if (
            provider === "GOOGLE" &&
            error instanceof GmailApiError &&
            error.status === 401
          ) {
            try {
              accessToken = await this.googleTokens.getAccessToken(
                cleanupJob.emailAccountId,
                true,
              );
              await this.gmail.trashMessage(
                accessToken,
                item.providerMessageId,
              );
              await this.prisma.message.update({
                where: { id: message.id },
                data: { isTrashed: true, isArchived: false },
              });
              await this.prisma.cleanupJobItem.update({
                where: { id: item.id },
                data: {
                  status: "COMPLETED",
                  errorCode: null,
                  processedAt: new Date(),
                },
              });
            } catch (retryError) {
              await this.markItemFailed(item.id, retryError);
            }
          } else {
            await this.markItemFailed(item.id, error);
          }
        }

        completedSinceProgress += 1;
        if (completedSinceProgress % 20 === 0) {
          await this.persistProgress(job, cleanupJob.id);
        }
      });

      const progress = await this.readProgress(cleanupJob.id);
      const configuredAttempts = job.opts.attempts ?? 1;
      const isFinalAttempt = job.attemptsMade + 1 >= configuredAttempts;
      if (progress.retryableFailures > 0 && !isFinalAttempt) {
        throw new Error("Some Gmail messages require a safe retry.");
      }
      const finalStatus =
        progress.failedMessages > 0 ? JobStatus.FAILED : JobStatus.COMPLETED;
      await this.prisma.cleanupJob.update({
        where: { id: cleanupJob.id },
        data: {
          status: finalStatus,
          processedMessages: progress.processedMessages,
          failedMessages: progress.failedMessages,
          completedAt: new Date(),
          activeKey: null,
        },
      });
      await this.runPostCompletionTasks(
        cleanupJob,
        finalStatus,
        progress.processedMessages,
        progress.failedMessages,
      );

      return {
        processedMessages: progress.processedMessages,
        failedMessages: progress.failedMessages,
        status: finalStatus,
      };
    } catch (error) {
      const configuredAttempts = job.opts.attempts ?? 1;
      const isFinalAttempt = job.attemptsMade + 1 >= configuredAttempts;
      await this.prisma.cleanupJob.update({
        where: { id: cleanupJob.id },
        data: {
          status: isFinalAttempt ? JobStatus.FAILED : JobStatus.QUEUED,
          completedAt: isFinalAttempt ? new Date() : null,
          activeKey: isFinalAttempt ? null : undefined,
        },
      });
      if (isFinalAttempt) {
        await this.safeAudit(cleanupJob.userId, cleanupJob.id, "FAILED");
      }
      throw error;
    }
  }

  private async markItemFailed(itemId: string, error: unknown) {
    const errorCode =
      error instanceof GmailApiError
        ? `GMAIL_${error.status}`
        : error instanceof Error
          ? error.constructor.name.slice(0, 100)
          : "UNKNOWN_ERROR";
    await this.prisma.cleanupJobItem.update({
      where: { id: itemId },
      data: { status: "FAILED", errorCode, processedAt: new Date() },
    });
  }

  private async readProgress(cleanupJobId: string) {
    const [processedMessages, retryableFailures, skippedMessages] =
      await Promise.all([
        this.prisma.cleanupJobItem.count({
          where: { cleanupJobId, status: "COMPLETED" },
        }),
        this.prisma.cleanupJobItem.count({
          where: { cleanupJobId, status: "FAILED" },
        }),
        this.prisma.cleanupJobItem.count({
          where: { cleanupJobId, status: "SKIPPED" },
        }),
      ]);
    return {
      processedMessages,
      retryableFailures,
      failedMessages: retryableFailures + skippedMessages,
    };
  }

  private async persistProgress(
    job: ProcessorJob<{ cleanupJobId: string }>,
    cleanupJobId: string,
  ) {
    const progress = await this.readProgress(cleanupJobId);
    await Promise.all([
      job.updateProgress(progress),
      this.prisma.cleanupJob.update({
        where: { id: cleanupJobId },
        data: {
          processedMessages: progress.processedMessages,
          failedMessages: progress.failedMessages,
        },
      }),
    ]);
  }

  private async runPostCompletionTasks(
    cleanupJob: { id: string; userId: string; emailAccountId: string },
    status: JobStatus,
    processedMessages: number,
    failedMessages: number,
  ) {
    await this.safeAudit(cleanupJob.userId, cleanupJob.id, status, {
      processedMessages,
      failedMessages,
    });
    for (const task of [
      () => this.gmailSync.recalculateAccount(cleanupJob.emailAccountId),
      () => this.gmailSync.refreshCleanupSuggestions(cleanupJob.emailAccountId),
    ]) {
      try {
        await task();
      } catch (error) {
        this.logger.error(
          JSON.stringify({
            event: "cleanup.post_completion.failed",
            targetId: cleanupJob.id,
            errorType:
              error instanceof Error ? error.constructor.name : "UnknownError",
          }),
        );
      }
    }
  }

  private async safeAudit(
    userId: string,
    cleanupJobId: string,
    status: JobStatus | "FAILED",
    metadata?: { processedMessages: number; failedMessages: number },
  ) {
    try {
      await this.prisma.auditLog.create({
        data: {
          userId,
          action: `cleanup.job.${status.toLowerCase()}`,
          targetType: "CleanupJob",
          targetId: cleanupJobId,
          metadata,
        },
      });
    } catch (error) {
      this.logger.error(
        JSON.stringify({
          event: "cleanup.audit.failed",
          targetId: cleanupJobId,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
    }
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
