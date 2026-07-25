import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from "@nestjs/common";
import { CleanupCategory, JobStatus, Prisma } from "@prisma/client";
import { PrismaService } from "../database/prisma.service";
import { DatabaseJobQueueService } from "../jobs/database-job-queue.service";

const CATEGORY_LABELS: Record<CleanupCategory, string> = {
  MARKETING: "Promotions",
  NEWSLETTERS: "Newsletters",
  SPAM: "Spam / Junk",
  OLD_UNREAD: "Old unread",
  LARGE_ATTACHMENTS: "Large attachments",
};

const ACTIVE_CLEANUP_STATUSES: JobStatus[] = [
  JobStatus.QUEUED,
  JobStatus.RUNNING,
];

@Injectable()
export class CleanupService {
  private readonly logger = new Logger(CleanupService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jobs: DatabaseJobQueueService,
  ) {}

  async getSuggestions(userId: string) {
    const suggestions = await this.prisma.cleanupSuggestion.findMany({
      where: { userId },
      orderBy: { messageCount: "desc" },
    });

    return {
      items: suggestions.map((suggestion) => ({
        id: suggestion.id,
        emailAccountId: suggestion.emailAccountId,
        messageCount: suggestion.messageCount,
        estimatedSpaceBytes: suggestion.estimatedSpaceBytes,
        status: suggestion.status,
        categoryKey: suggestion.category,
        category: CATEGORY_LABELS[suggestion.category],
      })),
    };
  }

  async createJob(
    userId: string,
    body: {
      emailAccountId: string;
      categories: string[];
      previewId: string;
    },
  ) {
    const account = await this.prisma.emailAccount.findFirst({
      where: { id: body.emailAccountId, userId },
      select: { id: true, userId: true },
    });
    if (!account) throw new NotFoundException("Email account was not found.");

    const categories = [...new Set(body.categories.map(normalizeCategory))];
    try {
      const cleanupJob = await this.prisma.$transaction(async (tx) => {
        const activeJob = await tx.cleanupJob.findFirst({
          where: {
            userId,
            emailAccountId: account.id,
            status: { in: ACTIVE_CLEANUP_STATUSES },
          },
          orderBy: { createdAt: "desc" },
          include: { _count: { select: { items: true } } },
        });
        if (activeJob) {
          if (isOrphanedCleanupJob(activeJob)) {
            await tx.cleanupJob.update({
              where: { id: activeJob.id },
              data: orphanedCleanupJobData(activeJob),
            });
          } else {
            return withoutItemCount(activeJob);
          }
        }

        const now = new Date();
        const plan = await tx.cleanupPlan.findFirst({
          where: {
            id: body.previewId,
            userId,
            emailAccountId: account.id,
            consumedAt: null,
            expiresAt: { gt: now },
          },
        });
        if (!plan) {
          throw new ConflictException(
            "The cleanup preview expired or was already used. Review the messages again.",
          );
        }

        const plannedCategories = parseStringArray(plan.categories).map(
          normalizeCategory,
        );
        if (!sameCategories(categories, plannedCategories)) {
          throw new BadRequestException(
            "The cleanup categories do not match the reviewed preview.",
          );
        }
        const plannedMessageIds = parseStringArray(plan.messageIds);
        const claimed = await tx.cleanupPlan.updateMany({
          where: {
            id: plan.id,
            consumedAt: null,
            expiresAt: { gt: now },
          },
          data: { consumedAt: now },
        });
        if (claimed.count !== 1) {
          throw new ConflictException(
            "The cleanup preview was already used. Review the messages again.",
          );
        }

        const messages = plannedMessageIds.length
          ? await tx.message.findMany({
              where: {
                ...buildCleanupMessageWhere(account.id, categories),
                id: { in: plannedMessageIds },
              },
              select: { id: true, providerMessageId: true, sizeBytes: true },
            })
          : [];
        const cleanupJob = await tx.cleanupJob.create({
          data: {
            userId: account.userId,
            emailAccountId: account.id,
            status:
              messages.length === 0 ? JobStatus.COMPLETED : JobStatus.QUEUED,
            totalMessages: messages.length,
            completedAt: messages.length === 0 ? now : undefined,
            activeKey:
              messages.length === 0
                ? null
                : cleanupOperationKey(userId, account.id),
            metadata: { categories, previewId: plan.id },
          },
        });
        if (messages.length > 0) {
          await tx.cleanupJobItem.createMany({
            data: messages.map((message) => ({
              cleanupJobId: cleanupJob.id,
              messageId: message.id,
              providerMessageId: message.providerMessageId,
              sizeBytes: message.sizeBytes ?? 0,
            })),
          });
        }
        return cleanupJob;
      });

      if (cleanupJob.totalMessages === 0) {
        await this.safeAudit(userId, cleanupJob.id, categories, 0);
        return cleanupJob;
      }
      const queueJob = await this.ensureCleanupQueued(cleanupJob.id);
      await this.safeAudit(
        userId,
        cleanupJob.id,
        categories,
        cleanupJob.totalMessages,
      );
      return { ...cleanupJob, queueJobId: queueJob.id };
    } catch (error) {
      if (isUniqueConstraintError(error)) {
        const activeJob = await this.prisma.cleanupJob.findFirst({
          where: {
            activeKey: cleanupOperationKey(userId, account.id),
            userId,
            emailAccountId: account.id,
            status: { in: ACTIVE_CLEANUP_STATUSES },
          },
        });
        if (activeJob) {
          const queueJob = await this.ensureCleanupQueued(activeJob.id);
          return { ...activeJob, queueJobId: queueJob.id };
        }
      }
      if (
        error instanceof BadRequestException ||
        error instanceof ConflictException ||
        error instanceof NotFoundException
      ) {
        throw error;
      }
      this.logger.error(
        JSON.stringify({
          event: "cleanup.queue.failed",
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
      throw new ServiceUnavailableException(
        "Cleanup could not be queued. Please retry.",
      );
    }
  }

  async preview(
    userId: string,
    body: { emailAccountId: string; categories: string[] },
  ) {
    const account = await this.prisma.emailAccount.findFirst({
      where: { id: body.emailAccountId, userId },
      select: { id: true, userId: true },
    });
    if (!account) throw new NotFoundException("Email account was not found.");

    const categories = [...new Set(body.categories.map(normalizeCategory))];
    const messages = await this.prisma.message.findMany({
      where: buildCleanupMessageWhere(account.id, categories),
      select: { id: true, sizeBytes: true },
    });
    const estimatedSpaceBytes = messages.reduce(
      (total, message) => total + (message.sizeBytes ?? 0),
      0,
    );
    const plan = await this.prisma.cleanupPlan.create({
      data: {
        userId: account.userId,
        emailAccountId: account.id,
        categories,
        messageIds: messages.map((message) => message.id),
        totalMessages: messages.length,
        estimatedSpaceBytes,
        expiresAt: new Date(Date.now() + 10 * 60 * 1_000),
      },
    });

    return {
      previewId: plan.id,
      emailAccountId: account.id,
      categories,
      totalMessages: messages.length,
      estimatedSpaceBytes,
    };
  }

  async getJob(userId: string, id: string) {
    const cleanupJob = await this.prisma.cleanupJob.findFirst({
      where: { id, userId },
      select: {
        id: true,
        status: true,
        totalMessages: true,
        processedMessages: true,
        failedMessages: true,
        startedAt: true,
        completedAt: true,
        createdAt: true,
        updatedAt: true,
        _count: { select: { items: true } },
      },
    });
    if (!cleanupJob) throw new NotFoundException("Cleanup job was not found.");
    if (isOrphanedCleanupJob(cleanupJob)) {
      return this.finalizeOrphanedJob(cleanupJob);
    }
    if (ACTIVE_CLEANUP_STATUSES.includes(cleanupJob.status)) {
      await this.ensureCleanupQueued(cleanupJob.id);
    }
    return withoutItemCount(cleanupJob);
  }

  async getActiveJobs(userId: string) {
    const jobs = await this.prisma.cleanupJob.findMany({
      where: {
        userId,
        status: { in: ACTIVE_CLEANUP_STATUSES },
      },
      select: {
        id: true,
        status: true,
        totalMessages: true,
        processedMessages: true,
        failedMessages: true,
        startedAt: true,
        createdAt: true,
        updatedAt: true,
        _count: { select: { items: true } },
      },
      orderBy: { createdAt: "desc" },
      take: 5,
    });
    const activeJobs = [];
    for (const job of jobs) {
      if (isOrphanedCleanupJob(job)) {
        await this.finalizeOrphanedJob(job);
        continue;
      }
      await this.ensureCleanupQueued(job.id);
      activeJobs.push(withoutItemCount(job));
    }
    return { items: activeJobs };
  }

  private async finalizeOrphanedJob(job: {
    id: string;
    userId?: string;
    totalMessages: number;
    processedMessages: number;
    failedMessages: number;
  }) {
    const finalized = await this.prisma.cleanupJob.update({
      where: { id: job.id },
      data: orphanedCleanupJobData(job),
      select: {
        id: true,
        status: true,
        totalMessages: true,
        processedMessages: true,
        failedMessages: true,
        startedAt: true,
        completedAt: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    this.logger.warn(
      JSON.stringify({
        event: "cleanup.orphan.finalized",
        targetId: job.id,
        processedMessages: job.processedMessages,
        failedMessages: finalized.failedMessages,
      }),
    );
    return finalized;
  }

  private async ensureCleanupQueued(cleanupJobId: string) {
    const bullJobId = `cleanup-${cleanupJobId}`;
    const existing = await this.jobs.getJob("cleanup", bullJobId);
    if (existing) {
      const state = await existing.getState();
      if (state !== "completed" && state !== "failed") return existing;
      await existing.remove();
    }
    return this.enqueueCleanup(cleanupJobId);
  }

  private enqueueCleanup(cleanupJobId: string) {
    return this.jobs.add(
      "cleanup",
      "trash-cleanup-messages",
      { cleanupJobId },
      {
        jobId: `cleanup-${cleanupJobId}`,
        attempts: 3,
        backoff: { type: "exponential", delay: 2_000 },
        removeOnComplete: { count: 100 },
        removeOnFail: { count: 500 },
      },
    );
  }

  private async safeAudit(
    userId: string,
    cleanupJobId: string,
    categories: CleanupCategory[],
    totalMessages: number,
  ) {
    try {
      await this.prisma.auditLog.create({
        data: {
          userId,
          action: "cleanup.job.created",
          targetType: "CleanupJob",
          targetId: cleanupJobId,
          metadata: { categories, totalMessages },
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
}

export function normalizeCategory(value: string): CleanupCategory {
  const normalized = value.trim().toUpperCase().replaceAll(" ", "_");
  const aliases: Record<string, CleanupCategory> = {
    PROMOTIONS: CleanupCategory.MARKETING,
    MARKETING: CleanupCategory.MARKETING,
    NEWSLETTERS: CleanupCategory.NEWSLETTERS,
    SPAM: CleanupCategory.SPAM,
    "SPAM_/_JUNK": CleanupCategory.SPAM,
    SUSPICIOUS: CleanupCategory.SPAM,
    OLD_UNREAD: CleanupCategory.OLD_UNREAD,
    LARGE_ATTACHMENTS: CleanupCategory.LARGE_ATTACHMENTS,
  };
  const category = aliases[normalized];
  if (!category)
    throw new NotFoundException(`Unknown cleanup category: ${value}`);
  return category;
}

export function buildCleanupMessageWhere(
  emailAccountId: string,
  categories: CleanupCategory[],
): Prisma.MessageWhereInput {
  const categoryConditions: Prisma.MessageWhereInput[] = categories.map(
    (category) => {
      switch (category) {
        case CleanupCategory.MARKETING:
          return { category: "PROMOTIONS" };
        case CleanupCategory.NEWSLETTERS:
          return { category: "NEWSLETTERS" };
        case CleanupCategory.SPAM:
          return { category: "SPAM" };
        case CleanupCategory.OLD_UNREAD:
          return {
            isRead: false,
            receivedAt: {
              lt: new Date(Date.now() - 90 * 24 * 60 * 60 * 1_000),
            },
          };
        case CleanupCategory.LARGE_ATTACHMENTS:
          return { sizeBytes: { gte: 5 * 1_024 * 1_024 } };
      }
    },
  );

  return {
    emailAccountId,
    isTrashed: false,
    isImportant: false,
    category: { not: "IMPORTANT" },
    sender: { isTrusted: false },
    OR: categoryConditions,
  };
}

function parseStringArray(value: Prisma.JsonValue): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === "string");
}

function sameCategories(
  left: CleanupCategory[],
  right: CleanupCategory[],
): boolean {
  return (
    [...new Set(left)].sort().join("|") === [...new Set(right)].sort().join("|")
  );
}

function cleanupOperationKey(userId: string, emailAccountId: string) {
  return `${userId}:${emailAccountId}`;
}

function isUniqueConstraintError(error: unknown) {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === "P2002"
  );
}

function isOrphanedCleanupJob(job: {
  status: JobStatus;
  totalMessages: number;
  _count: { items: number };
}) {
  return (
    ACTIVE_CLEANUP_STATUSES.includes(job.status) &&
    job.totalMessages > 0 &&
    job._count.items === 0
  );
}

function orphanedCleanupJobData(job: {
  totalMessages: number;
  processedMessages: number;
  failedMessages: number;
}) {
  return {
    status: JobStatus.FAILED,
    failedMessages: Math.max(
      job.failedMessages,
      Math.max(0, job.totalMessages - job.processedMessages),
    ),
    completedAt: new Date(),
    activeKey: null,
  };
}

function withoutItemCount<T extends { _count: { items: number } }>(job: T) {
  const { _count, ...result } = job;
  void _count;
  return result;
}
