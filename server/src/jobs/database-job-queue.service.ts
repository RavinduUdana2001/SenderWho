import { Injectable } from "@nestjs/common";
import { BackgroundJob, BackgroundJobStatus, Prisma } from "@prisma/client";
import { randomUUID } from "node:crypto";
import { PrismaService } from "../database/prisma.service";

export type DatabaseJobOptions = {
  jobId?: string;
  deduplication?: { id: string };
  attempts?: number;
  backoff?: { type: "exponential" | "fixed"; delay: number };
  removeOnComplete?: unknown;
  removeOnFail?: unknown;
};

export type ProcessorJob<T> = {
  id: string;
  data: T;
  attemptsMade: number;
  opts: { attempts: number };
  updateProgress(progress: unknown): Promise<void>;
};

export class QueuedDatabaseJob<T = unknown> {
  constructor(
    private readonly queueService: DatabaseJobQueueService,
    readonly record: BackgroundJob,
  ) {}

  get id() {
    return this.record.id;
  }

  get data() {
    return this.record.payload as T;
  }

  async getState() {
    return this.record.status.toLowerCase();
  }

  async remove() {
    await this.queueService.remove(this.record.id);
  }
}

@Injectable()
export class DatabaseJobQueueService {
  constructor(private readonly prisma: PrismaService) {}

  async add<T>(
    queue: string,
    taskName: string,
    data: T,
    options: DatabaseJobOptions = {},
  ): Promise<QueuedDatabaseJob<T>> {
    if (this.prisma.mockDataEnabled) {
      return new QueuedDatabaseJob(this, {
        id: options.jobId ?? `mock-${taskName}`,
        queue,
        taskName,
        payload: data as Prisma.JsonValue,
        status: BackgroundJobStatus.QUEUED,
        attempts: 0,
        maxAttempts: options.attempts ?? 1,
        backoffMs: options.backoff?.delay ?? 0,
        availableAt: new Date(),
        leaseOwner: null,
        leaseExpiresAt: null,
        progress: null,
        result: null,
        lastError: null,
        startedAt: null,
        completedAt: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      } as BackgroundJob);
    }

    const id =
      options.jobId ??
      (options.deduplication?.id
        ? `${queue}-${options.deduplication.id}`
        : `${queue}-${randomUUID()}`);
    const existing = await this.prisma.backgroundJob.findUnique({
      where: { id },
    });
    if (
      existing &&
      (existing.status === BackgroundJobStatus.QUEUED ||
        existing.status === BackgroundJobStatus.RUNNING)
    ) {
      return new QueuedDatabaseJob<T>(this, existing);
    }

    const values = {
      queue,
      taskName,
      payload: data as Prisma.InputJsonValue,
      status: BackgroundJobStatus.QUEUED,
      attempts: 0,
      maxAttempts: Math.max(1, options.attempts ?? 1),
      backoffMs: Math.max(0, options.backoff?.delay ?? 0),
      availableAt: new Date(),
      leaseOwner: null,
      leaseExpiresAt: null,
      progress: Prisma.JsonNull,
      result: Prisma.JsonNull,
      lastError: null,
      startedAt: null,
      completedAt: null,
    } as const;
    let record: BackgroundJob;
    try {
      record = existing
        ? await this.prisma.backgroundJob.update({
            where: { id },
            data: values,
          })
        : await this.prisma.backgroundJob.create({
            data: { id, ...values },
          });
    } catch (error) {
      if (!isUniqueConflict(error)) throw error;
      record = await this.prisma.backgroundJob.findUniqueOrThrow({
        where: { id },
      });
    }
    return new QueuedDatabaseJob<T>(this, record);
  }

  async getJob<T>(queue: string, id: string) {
    if (this.prisma.mockDataEnabled) return null;
    const record = await this.prisma.backgroundJob.findFirst({
      where: { id, queue },
    });
    return record ? new QueuedDatabaseJob<T>(this, record) : null;
  }

  async remove(id: string) {
    if (this.prisma.mockDataEnabled) return;
    await this.prisma.backgroundJob.deleteMany({
      where: {
        id,
        status: {
          in: [
            BackgroundJobStatus.COMPLETED,
            BackgroundJobStatus.FAILED,
            BackgroundJobStatus.CANCELED,
          ],
        },
      },
    });
  }

  async recoverExpiredLeases(now = new Date()) {
    if (this.prisma.mockDataEnabled) return 0;
    const result = await this.prisma.backgroundJob.updateMany({
      where: {
        status: BackgroundJobStatus.RUNNING,
        leaseExpiresAt: { lt: now },
      },
      data: {
        status: BackgroundJobStatus.QUEUED,
        leaseOwner: null,
        leaseExpiresAt: null,
        availableAt: now,
        lastError: "Worker lease expired; job safely returned to the queue.",
      },
    });
    return result.count;
  }

  async claim(queue: string, owner: string, leaseMs: number) {
    if (this.prisma.mockDataEnabled) return null;
    for (let collision = 0; collision < 5; collision += 1) {
      const now = new Date();
      const candidate = await this.prisma.backgroundJob.findFirst({
        where: {
          queue,
          status: BackgroundJobStatus.QUEUED,
          availableAt: { lte: now },
        },
        orderBy: [{ availableAt: "asc" }, { createdAt: "asc" }],
        select: { id: true },
      });
      if (!candidate) return null;
      const claimed = await this.prisma.backgroundJob.updateMany({
        where: {
          id: candidate.id,
          status: BackgroundJobStatus.QUEUED,
          availableAt: { lte: now },
        },
        data: {
          status: BackgroundJobStatus.RUNNING,
          attempts: { increment: 1 },
          leaseOwner: owner,
          leaseExpiresAt: new Date(now.getTime() + leaseMs),
          startedAt: now,
          lastError: null,
        },
      });
      if (claimed.count === 1) {
        return this.prisma.backgroundJob.findUnique({
          where: { id: candidate.id },
        });
      }
    }
    return null;
  }

  async extendLease(id: string, owner: string, leaseMs: number) {
    await this.prisma.backgroundJob.updateMany({
      where: { id, status: BackgroundJobStatus.RUNNING, leaseOwner: owner },
      data: { leaseExpiresAt: new Date(Date.now() + leaseMs) },
    });
  }

  async updateProgress(id: string, owner: string, progress: unknown) {
    await this.prisma.backgroundJob.updateMany({
      where: { id, status: BackgroundJobStatus.RUNNING, leaseOwner: owner },
      data: { progress: progress as Prisma.InputJsonValue },
    });
  }

  async complete(id: string, owner: string, result: unknown) {
    await this.prisma.backgroundJob.updateMany({
      where: { id, status: BackgroundJobStatus.RUNNING, leaseOwner: owner },
      data: {
        status: BackgroundJobStatus.COMPLETED,
        result: result as Prisma.InputJsonValue,
        completedAt: new Date(),
        leaseOwner: null,
        leaseExpiresAt: null,
      },
    });
  }

  async fail(record: BackgroundJob, owner: string, error: unknown) {
    const retry = record.attempts < record.maxAttempts;
    const multiplier = Math.max(0, record.attempts - 1);
    const delay = Math.min(record.backoffMs * 2 ** multiplier, 15 * 60_000);
    await this.prisma.backgroundJob.updateMany({
      where: {
        id: record.id,
        status: BackgroundJobStatus.RUNNING,
        leaseOwner: owner,
      },
      data: {
        status: retry ? BackgroundJobStatus.QUEUED : BackgroundJobStatus.FAILED,
        availableAt: retry ? new Date(Date.now() + delay) : undefined,
        completedAt: retry ? null : new Date(),
        leaseOwner: null,
        leaseExpiresAt: null,
        lastError: safeError(error),
      },
    });
  }

  async countRunnable() {
    return this.prisma.backgroundJob.count({
      where: {
        status: {
          in: [BackgroundJobStatus.QUEUED, BackgroundJobStatus.RUNNING],
        },
      },
    });
  }
}

function safeError(error: unknown) {
  return error instanceof Error
    ? `${error.constructor.name}: ${error.message}`.slice(0, 1_000)
    : "Unknown background-job error";
}

function isUniqueConflict(error: unknown) {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === "P2002"
  );
}
