import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from "@nestjs/common";
import { BackgroundHealthService } from "../common/background-health.service";
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
  private retryAt = 0;
  private failures = 0;
  private faultRevision = 0;
  private readonly leaseFailures = new Set<string>();

  constructor(
    private readonly jobs: DatabaseJobQueueService,
    private readonly scanProcessor: ScanInboxProcessor,
    private readonly cleanupProcessor: CleanupProcessor,
    private readonly unsubscribeProcessor: UnsubscribeProcessor,
    private readonly health: BackgroundHealthService = new BackgroundHealthService(),
  ) {}

  onModuleInit() {
    this.health.register("jobWorker", 60_000);
    this.health.register("workerLeases", 90_000);
    this.timer = setInterval(() => void this.poll(), POLL_MS);
    this.timer.unref();
    void this.poll();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
    this.health.remove("jobWorker");
    this.health.remove("workerLeases");
  }

  private async poll() {
    if (this.polling || Date.now() < this.retryAt) return;
    this.polling = true;
    const revision = this.faultRevision;
    try {
      // Stop claiming more work while renewal of an active lease is uncertain.
      if (this.leaseFailures.size > 0) return;
      this.health.success("workerLeases");
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
          void this.run(record, definition.process)
            .catch((error) => {
              this.faultRevision++;
              this.health.failure("jobWorker");
              this.logger.error(
                JSON.stringify({
                  event: "database_queue.job_record_failed",
                  targetId: record.id,
                  errorType:
                    error instanceof Error
                      ? error.constructor.name
                      : "UnknownError",
                }),
              );
            })
            .finally(() => {
              this.running.set(
                definition.queue,
                Math.max(0, (this.running.get(definition.queue) ?? 1) - 1),
              );
            });
        }
      }
      this.failures = 0;
      this.retryAt = 0;
      if (revision === this.faultRevision) this.health.success("jobWorker");
    } catch (error) {
      this.health.failure("jobWorker");
      this.retryAt =
        Date.now() +
        Math.min(1_000 * 2 ** Math.min(this.failures++, 5), 30_000);
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
    const controller = new AbortController();
    let finished = false;
    let renewing = false;
    let expiry: NodeJS.Timeout;
    const loseLease = () => {
      this.leaseFailures.add(record.id);
      this.health.failure("workerLeases");
      controller.abort(new Error("Worker lease is no longer safe"));
    };
    const resetExpiry = () => {
      if (expiry) clearTimeout(expiry);
      expiry = setTimeout(loseLease, LEASE_MS - 5_000);
      expiry.unref();
    };
    resetExpiry();
    const renew = async () => {
      if (finished || renewing || controller.signal.aborted) return;
      renewing = true;
      try {
        const owned = await this.jobs.extendLease(
          record.id,
          this.owner,
          LEASE_MS,
        );
        if (finished || controller.signal.aborted) return;
        if (!owned) {
          loseLease();
          return;
        }
        resetExpiry();
        this.leaseFailures.delete(record.id);
        if (this.leaseFailures.size === 0) this.health.success("workerLeases");
      } catch (error) {
        if (!finished) {
          this.leaseFailures.add(record.id);
          this.health.failure("workerLeases");
          this.logger.error(
            JSON.stringify({
              event: "database_queue.lease_renewal_failed",
              targetId: record.id,
              errorType:
                error instanceof Error
                  ? error.constructor.name
                  : "UnknownError",
            }),
          );
        }
      } finally {
        renewing = false;
      }
    };
    const heartbeat = setInterval(() => void renew(), HEARTBEAT_MS);
    heartbeat.unref();
    const job: ProcessorJob<any> = {
      id: record.id,
      data: record.payload,
      attemptsMade: Math.max(0, record.attempts - 1),
      opts: { attempts: record.maxAttempts },
      signal: controller.signal,
      updateProgress: (progress) => {
        controller.signal.throwIfAborted();
        return this.jobs.updateProgress(record.id, this.owner, progress);
      },
    };
    try {
      controller.signal.throwIfAborted();
      const result = await process(job);
      controller.signal.throwIfAborted();
      await this.jobs.complete(record.id, this.owner, result ?? {});
      if (record.queue === "scan-inbox" && isGmailContinuationResult(result)) {
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
      finished = true;
      clearInterval(heartbeat);
      clearTimeout(expiry!);
      this.leaseFailures.delete(record.id);
      if (this.leaseFailures.size === 0) this.health.success("workerLeases");
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
