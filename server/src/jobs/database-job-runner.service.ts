import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from "@nestjs/common";
import { BackgroundJob } from "@prisma/client";
import { randomUUID } from "node:crypto";
import { CleanupProcessor } from "./cleanup.processor";
import {
  DatabaseJobQueueService,
  ProcessorJob,
} from "./database-job-queue.service";
import { ScanInboxProcessor } from "./scan-inbox.processor";
import { UnsubscribeProcessor } from "./unsubscribe.processor";

const POLL_MS = 1_000;
const LEASE_MS = 2 * 60_000;
const HEARTBEAT_MS = 30_000;

@Injectable()
export class DatabaseJobRunner implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DatabaseJobRunner.name);
  private readonly owner = `${process.pid}-${randomUUID()}`;
  private readonly running = new Map<string, number>();
  private timer?: NodeJS.Timeout;
  private polling = false;

  constructor(
    private readonly jobs: DatabaseJobQueueService,
    private readonly scanProcessor: ScanInboxProcessor,
    private readonly cleanupProcessor: CleanupProcessor,
    private readonly unsubscribeProcessor: UnsubscribeProcessor,
  ) {}

  onModuleInit() {
    this.timer = setInterval(() => void this.poll(), POLL_MS);
    this.timer.unref();
    void this.poll();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  private async poll() {
    if (this.polling) return;
    this.polling = true;
    try {
      await this.jobs.recoverExpiredLeases();
      for (const definition of this.definitions()) {
        const active = this.running.get(definition.queue) ?? 0;
        for (let slot = active; slot < definition.concurrency; slot += 1) {
          const record = await this.jobs.claim(
            definition.queue,
            this.owner,
            LEASE_MS,
          );
          if (!record) break;
          this.running.set(
            definition.queue,
            (this.running.get(definition.queue) ?? 0) + 1,
          );
          void this.run(record, definition.process).finally(() => {
            this.running.set(
              definition.queue,
              Math.max(0, (this.running.get(definition.queue) ?? 1) - 1),
            );
          });
        }
      }
    } catch (error) {
      this.logger.error(
        JSON.stringify({
          event: "database_queue.poll_failed",
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
    } finally {
      this.polling = false;
    }
  }

  private definitions() {
    return [
      {
        queue: "scan-inbox",
        concurrency: 2,
        process: (job: ProcessorJob<{ emailAccountId: string }>) =>
          this.scanProcessor.process(job),
      },
      {
        queue: "cleanup",
        concurrency: 2,
        process: (job: ProcessorJob<{ cleanupJobId: string }>) =>
          this.cleanupProcessor.process(job),
      },
      {
        queue: "unsubscribe",
        concurrency: 4,
        process: (job: ProcessorJob<{ unsubscribeJobId: string }>) =>
          this.unsubscribeProcessor.process(job),
      },
    ];
  }

  private async run(
    record: BackgroundJob,
    process: (job: ProcessorJob<any>) => Promise<unknown>,
  ) {
    const heartbeat = setInterval(
      () => void this.jobs.extendLease(record.id, this.owner, LEASE_MS),
      HEARTBEAT_MS,
    );
    heartbeat.unref();
    const job: ProcessorJob<any> = {
      id: record.id,
      data: record.payload,
      attemptsMade: Math.max(0, record.attempts - 1),
      opts: { attempts: record.maxAttempts },
      updateProgress: (progress) =>
        this.jobs.updateProgress(record.id, this.owner, progress),
    };
    try {
      const result = await process(job);
      await this.jobs.complete(record.id, this.owner, result ?? {});
      if (
        record.queue === "scan-inbox" &&
        isGmailContinuationResult(result)
      ) {
        await this.jobs.add(
          "scan-inbox",
          "sync-gmail-account",
          { emailAccountId: result.emailAccountId },
          {
            deduplication: { id: `scan-${result.emailAccountId}` },
            attempts: 4,
            backoff: { type: "exponential", delay: 2_000 },
          },
        );
      }
    } catch (error) {
      await this.jobs.fail(record, this.owner, error);
      this.logger.warn(
        JSON.stringify({
          event: "database_queue.job_failed",
          queue: record.queue,
          targetId: record.id,
          attempt: record.attempts,
          maxAttempts: record.maxAttempts,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
    } finally {
      clearInterval(heartbeat);
    }
  }
}

function isGmailContinuationResult(
  result: unknown,
): result is { emailAccountId: string; needsContinuation: true } {
  if (typeof result !== "object" || result === null) return false;
  const candidate = result as Record<string, unknown>;
  return (
    candidate.needsContinuation === true &&
    typeof candidate.emailAccountId === "string"
  );
}
