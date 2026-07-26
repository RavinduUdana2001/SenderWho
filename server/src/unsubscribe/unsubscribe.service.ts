import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from "@nestjs/common";
import { JobStatus, Prisma, UnsubscribeMethod } from "@prisma/client";
import { mockSenders } from "../common/mock/senderwho.mock";
import { PrismaService } from "../database/prisma.service";
import { DatabaseJobQueueService } from "../jobs/database-job-queue.service";

@Injectable()
export class UnsubscribeService {
  private readonly logger = new Logger(UnsubscribeService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jobs: DatabaseJobQueueService,
  ) {}

  async getCandidates(userId: string) {
    if (this.prisma.mockDataEnabled) {
      return {
        items: mockSenders
          .filter(
            (sender) => sender.score < 80 || sender.category === "Promotions",
          )
          .map((sender) => ({
            id: sender.id,
            name: sender.name,
            email: sender.email,
            reason: "Frequent marketing sender",
            colorKey: sender.colorKey,
          })),
      };
    }

    const senders = await this.prisma.sender.findMany({
      where: {
        userId,
        isTrusted: false,
        isBlocked: false,
        messages: {
          some: {
            isTrashed: false,
            listUnsubscribePost: true,
            listUnsubscribeUrl: { not: null },
          },
        },
        unsubscribeJobs: {
          none: { status: JobStatus.COMPLETED },
        },
      },
      include: {
        messages: {
          where: {
            isTrashed: false,
            listUnsubscribePost: true,
            listUnsubscribeUrl: { not: null },
          },
          orderBy: { receivedAt: "desc" },
          take: 1,
          select: { receivedAt: true },
        },
      },
      orderBy: [{ trustScore: "asc" }, { totalMessages: "desc" }],
      take: 25,
    });

    return {
      items: senders.map((sender) => ({
        id: sender.id,
        name: sender.name ?? sender.email,
        email: sender.email,
        reason: "Supports secure one-click unsubscribe",
        colorKey: sender.riskLevel === "HIGH" ? "danger" : "warning",
        lastMessageAt: sender.messages[0]?.receivedAt,
      })),
    };
  }

  async createJob(userId: string, senderId: string) {
    if (this.prisma.mockDataEnabled) {
      const mockSender = mockSenders.find((sender) => sender.id === senderId);
      if (!mockSender) throw new NotFoundException("Sender was not found.");
      return {
        id: `unsubscribe_${senderId}`,
        status: "QUEUED",
        queue: "unsubscribe",
        senderId,
        sender: mockSender,
      };
    }

    let existing = await this.prisma.unsubscribeJob.findFirst({
      where: {
        userId,
        senderId,
        status: {
          in: [
            JobStatus.QUEUED,
            JobStatus.RUNNING,
            JobStatus.COMPLETED,
            JobStatus.FAILED,
          ],
        },
      },
      orderBy: { createdAt: "desc" },
    });
    if (
      existing?.status === JobStatus.COMPLETED ||
      existing?.status === JobStatus.RUNNING ||
      existing?.status === JobStatus.QUEUED
    ) {
      if (existing.status !== JobStatus.COMPLETED) {
        await this.enqueueUnsubscribe(
          existing.id,
          this.retryAttempt(existing.metadata),
        );
      }
      return existing;
    }

    const sender = await this.prisma.sender.findFirst({
      where: { id: senderId, userId },
      include: {
        messages: {
          where: {
            isTrashed: false,
            listUnsubscribePost: true,
            listUnsubscribeUrl: { not: null },
          },
          orderBy: { receivedAt: "desc" },
          take: 1,
          select: { listUnsubscribeUrl: true, providerMessageId: true },
        },
      },
    });
    if (!sender) throw new NotFoundException("Sender was not found.");

    const sourceMessage = sender.messages[0];
    const unsubscribeUrl = sourceMessage?.listUnsubscribeUrl;
    if (!unsubscribeUrl?.startsWith("https://")) {
      throw new BadRequestException(
        "This sender does not support secure one-click unsubscribe.",
      );
    }

    const operationKey = unsubscribeOperationKey(userId, sender.id);
    const retryAttempt = existing
      ? this.retryAttempt(existing.metadata) + 1
      : 0;
    let unsubscribeJob;
    try {
      unsubscribeJob = existing
        ? await this.prisma.unsubscribeJob.update({
            where: { id: existing.id },
            data: {
              status: JobStatus.QUEUED,
              completedAt: null,
              method: UnsubscribeMethod.LIST_UNSUBSCRIBE_HEADER,
              unsubscribeUrl,
              operationKey,
              metadata: {
                providerMessageId: sourceMessage.providerMessageId,
                retryAttempt,
              },
            },
          })
        : await this.prisma.unsubscribeJob.create({
            data: {
              userId: sender.userId,
              senderId: sender.id,
              status: JobStatus.QUEUED,
              method: UnsubscribeMethod.LIST_UNSUBSCRIBE_HEADER,
              unsubscribeUrl,
              operationKey,
              metadata: {
                providerMessageId: sourceMessage.providerMessageId,
                retryAttempt,
              },
            },
          });
    } catch (error) {
      if (!isUniqueConstraintError(error)) throw error;
      existing = await this.prisma.unsubscribeJob.findUnique({
        where: { operationKey },
      });
      if (!existing) throw error;
      unsubscribeJob = existing;
    }

    try {
      const queueJob = await this.enqueueUnsubscribe(
        unsubscribeJob.id,
        retryAttempt,
      );
      await this.safeAudit(userId, unsubscribeJob.id, sender.id);
      return { ...unsubscribeJob, queueJobId: queueJob.id };
    } catch (error) {
      this.logger.error(
        JSON.stringify({
          event: "unsubscribe.queue.failed",
          targetId: unsubscribeJob.id,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
      throw new ServiceUnavailableException(
        "Unsubscribe could not be queued. Please retry.",
      );
    }
  }

  async createJobs(userId: string, senderIds: string[]) {
    const jobs: Array<Awaited<ReturnType<UnsubscribeService["createJob"]>>> =
      [];
    const failures: Array<{ senderId: string; reason: string }> = [];
    for (const senderId of [...new Set(senderIds)]) {
      try {
        jobs.push(await this.createJob(userId, senderId));
      } catch {
        failures.push({
          senderId,
          reason: "This unsubscribe request could not be queued.",
        });
      }
    }
    return {
      requested: senderIds.length,
      queued: jobs.length,
      failed: failures.length,
      jobs,
      failures,
    };
  }

  async getJob(userId: string, id: string) {
    if (this.prisma.mockDataEnabled) {
      return {
        id,
        status: "COMPLETED",
      };
    }

    const unsubscribeJob = await this.prisma.unsubscribeJob.findFirst({
      where: { id, userId },
      select: {
        id: true,
        senderId: true,
        status: true,
        method: true,
        createdAt: true,
        completedAt: true,
        metadata: true,
      },
    });
    if (!unsubscribeJob) {
      throw new NotFoundException("Unsubscribe job was not found.");
    }
    return this.jobResponse(unsubscribeJob);
  }

  async getJobs(userId: string, ids: string[]) {
    const jobs = await this.prisma.unsubscribeJob.findMany({
      where: { userId, id: { in: [...new Set(ids)] } },
      select: {
        id: true,
        senderId: true,
        status: true,
        method: true,
        createdAt: true,
        completedAt: true,
        metadata: true,
      },
    });
    const byId = new Map(jobs.map((job) => [job.id, job]));
    return {
      items: ids
        .map((id) => byId.get(id))
        .filter((job) => job != null)
        .map((job) => this.jobResponse(job!)),
    };
  }

  async getActiveJobs(userId: string) {
    if (this.prisma.mockDataEnabled) return { items: [] };

    const jobs = await this.prisma.unsubscribeJob.findMany({
      where: {
        userId,
        // Restore failed rows as well so an app restart/refresh keeps the
        // provider failure and explicit retry action attached to its sender.
        status: {
          in: [JobStatus.QUEUED, JobStatus.RUNNING, JobStatus.FAILED],
        },
      },
      select: {
        id: true,
        senderId: true,
        status: true,
        method: true,
        createdAt: true,
        completedAt: true,
        metadata: true,
      },
      orderBy: { createdAt: "desc" },
      take: 25,
    });
    // A process restart or a previously failed queue insertion can leave a DB
    // row queued without a runnable durable-job entry. Reconcile only QUEUED rows;
    // RUNNING rows may already have reached the provider and must never be
    // replayed automatically. FAILED rows are shown for explicit user retry.
    await Promise.allSettled(
      jobs
        .filter((job) => job.status === JobStatus.QUEUED)
        .map((job) =>
          this.enqueueUnsubscribe(job.id, this.retryAttempt(job.metadata)),
        ),
    );
    return { items: jobs.map((job) => this.jobResponse(job)) };
  }

  private jobResponse<T extends { status: JobStatus; metadata?: unknown }>(
    job: T,
  ) {
    return {
      ...job,
      failureReason:
        job.status === JobStatus.FAILED
          ? this.safeFailureReason(job.metadata)
          : undefined,
      metadata: undefined,
    };
  }

  private safeFailureReason(metadata: unknown) {
    const value =
      metadata && typeof metadata === "object" && !Array.isArray(metadata)
        ? (metadata as Record<string, unknown>).error
        : undefined;
    if (typeof value !== "string") {
      return "The sender could not complete the one-click request.";
    }
    const error = value.toLowerCase();
    if (error.includes("enotfound") || error.includes("eai_again")) {
      return "The sender's unsubscribe service is currently unavailable.";
    }
    if (error.includes("timed out") || error.includes("timeout")) {
      return "The sender's unsubscribe service did not respond in time.";
    }
    if (error.includes("outcome") && error.includes("unknown")) {
      return "The previous request outcome could not be confirmed.";
    }
    return "The sender rejected or could not complete the one-click request.";
  }

  private retryAttempt(metadata: unknown) {
    const value =
      metadata && typeof metadata === "object" && !Array.isArray(metadata)
        ? (metadata as Record<string, unknown>).retryAttempt
        : undefined;
    return typeof value === "number" &&
      Number.isSafeInteger(value) &&
      value >= 0
      ? value
      : 0;
  }

  private async enqueueUnsubscribe(unsubscribeJobId: string, retryAttempt = 0) {
    const queueJobId =
      retryAttempt === 0
        ? `unsubscribe-${unsubscribeJobId}`
        : `unsubscribe-${unsubscribeJobId}-attempt-${retryAttempt}`;
    const existingQueueJob = await this.jobs.getJob("unsubscribe", queueJobId);
    if (existingQueueJob) {
      const state = await existingQueueJob.getState();
      if (state === "failed" || state === "completed") {
        await existingQueueJob.remove();
      } else {
        return existingQueueJob;
      }
    }
    return this.jobs.add(
      "unsubscribe",
      "one-click-unsubscribe",
      { unsubscribeJobId },
      {
        jobId: queueJobId,
        attempts: 1,
        removeOnComplete: { count: 100 },
        removeOnFail: { count: 500 },
      },
    );
  }

  private async safeAudit(
    userId: string,
    unsubscribeJobId: string,
    senderId: string,
  ) {
    try {
      await this.prisma.auditLog.create({
        data: {
          userId,
          action: "unsubscribe.job.created",
          targetType: "UnsubscribeJob",
          targetId: unsubscribeJobId,
          metadata: {
            senderId,
            method: UnsubscribeMethod.LIST_UNSUBSCRIBE_HEADER,
          },
        },
      });
    } catch (error) {
      this.logger.error(
        JSON.stringify({
          event: "unsubscribe.audit.failed",
          targetId: unsubscribeJobId,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
    }
  }
}

function unsubscribeOperationKey(userId: string, senderId: string) {
  return `${userId}:${senderId}`;
}

function isUniqueConstraintError(error: unknown) {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === "P2002"
  );
}
