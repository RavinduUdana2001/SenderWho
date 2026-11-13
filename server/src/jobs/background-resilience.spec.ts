import "reflect-metadata";
import { ConfigService } from "@nestjs/config";
import { BackgroundHealthService } from "../common/background-health.service";
import { InboxScanScheduler } from "./inbox-scan.scheduler";
import { DataRetentionService } from "../users/data-retention.service";
import { DatabaseJobRunner } from "./database-job-runner.service";
import { HealthController } from "../health.controller";

const deferred = <T>() => {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => {
    resolve = done;
  });
  return { promise, resolve };
};
const record = {
  id: "job",
  queue: "scan-inbox",
  payload: { emailAccountId: "account" },
  attempts: 1,
  maxAttempts: 4,
};

describe("background failure containment and readiness", () => {
  beforeEach(() => jest.useFakeTimers());
  afterEach(() => jest.useRealTimers());

  it("contains scheduler database failures, backs off, and recovers without overlapping runs", async () => {
    const health = new BackgroundHealthService();
    const findMany = jest
      .fn()
      .mockRejectedValueOnce(new Error("private db diagnostic"))
      .mockResolvedValue([]);
    const scheduler = new InboxScanScheduler(
      { emailAccount: { findMany } } as never,
      {} as never,
      health,
    );
    scheduler.onModuleInit();
    await jest.advanceTimersByTimeAsync(15_000);
    expect(health.snapshot().scanScheduler).toEqual({
      status: "down",
      reason: "unavailable",
    });
    await jest.advanceTimersByTimeAsync(15_000);
    expect(health.snapshot().scanScheduler).toEqual({ status: "up" });
    expect(findMany).toHaveBeenCalledTimes(2);
    scheduler.onModuleDestroy();
    await jest.advanceTimersByTimeAsync(90_000);
    expect(findMany).toHaveBeenCalledTimes(2);
  });

  it("retries retention after a failure and never overlaps a pending run", async () => {
    const health = new BackgroundHealthService();
    const tables = [
      "oAuthLoginSession",
      "appSession",
      "idempotencyRecord",
      "message",
      "auditLog",
      "cleanupJob",
      "unsubscribeJob",
      "backgroundJob",
      "apiRateLimit",
    ];
    const prisma: any = Object.fromEntries(
      tables.map((name) => [
        name,
        { deleteMany: jest.fn().mockResolvedValue({ count: 0 }) },
      ]),
    );
    const pending = deferred<any[]>();
    prisma.$transaction = jest
      .fn()
      .mockRejectedValueOnce(new Error("db unavailable"))
      .mockReturnValueOnce(pending.promise);
    const retention = new DataRetentionService(
      prisma,
      new ConfigService(),
      health,
    );
    retention.onModuleInit();
    await expect(retention.run()).resolves.toBeUndefined();
    expect(health.snapshot().dataRetention.status).toBe("down");
    await jest.advanceTimersByTimeAsync(60_000);
    await retention.run();
    expect(prisma.$transaction).toHaveBeenCalledTimes(2);
    pending.resolve(tables.map(() => ({ count: 0 })));
    await jest.advanceTimersByTimeAsync(1);
    expect(health.snapshot().dataRetention.status).toBe("up");
    retention.onModuleDestroy();
  });

  it("contains a failed queue failure-write instead of leaking a rejected fire-and-forget promise", async () => {
    const health = new BackgroundHealthService();
    const jobs = {
      recoverExpiredLeases: jest.fn().mockResolvedValue(0),
      claim: jest.fn().mockResolvedValueOnce(record).mockResolvedValue(null),
      fail: jest.fn().mockRejectedValue(new Error("db unavailable")),
    };
    const runner = new DatabaseJobRunner(
      jobs as never,
      {
        process: jest.fn().mockRejectedValue(new Error("processor failed")),
      } as never,
      {} as never,
      {} as never,
      health,
    );
    runner.onModuleInit();
    await jest.advanceTimersByTimeAsync(1);
    expect(jobs.fail).toHaveBeenCalledTimes(1);
    expect(health.snapshot().jobWorker.status).toBe("down");
    await jest.advanceTimersByTimeAsync(1000);
    expect(health.snapshot().jobWorker.status).toBe("up");
    runner.onModuleDestroy();
  });

  it("catches heartbeat failure, blocks new claims, and resumes after renewal succeeds", async () => {
    const health = new BackgroundHealthService();
    const processing = deferred<object>();
    const jobs = {
      recoverExpiredLeases: jest.fn().mockResolvedValue(0),
      claim: jest.fn().mockResolvedValueOnce(record).mockResolvedValue(null),
      extendLease: jest
        .fn()
        .mockRejectedValueOnce(new Error("temporary db outage"))
        .mockResolvedValue(true),
      complete: jest.fn().mockResolvedValue(undefined),
      fail: jest.fn().mockResolvedValue(undefined),
    };
    const runner = new DatabaseJobRunner(
      jobs as never,
      { process: () => processing.promise } as never,
      {} as never,
      {} as never,
      health,
    );
    runner.onModuleInit();
    await jest.advanceTimersByTimeAsync(30_001);
    expect(health.snapshot().workerLeases.status).toBe("down");
    const claims = jobs.claim.mock.calls.length;
    await jest.advanceTimersByTimeAsync(10_000);
    expect(jobs.claim).toHaveBeenCalledTimes(claims);
    await jest.advanceTimersByTimeAsync(20_000);
    expect(health.snapshot().workerLeases.status).toBe("up");
    processing.resolve({});
    await jest.advanceTimersByTimeAsync(1);
    expect(jobs.complete).toHaveBeenCalledTimes(1);
    runner.onModuleDestroy();
  });

  it("aborts work on a lost lease and does not mark it completed", async () => {
    const health = new BackgroundHealthService();
    const pending = deferred<object>();
    let signal: AbortSignal | undefined;
    const jobs = {
      recoverExpiredLeases: jest.fn().mockResolvedValue(0),
      claim: jest.fn().mockResolvedValueOnce(record).mockResolvedValue(null),
      extendLease: jest.fn().mockResolvedValue(false),
      complete: jest.fn(),
      fail: jest.fn().mockResolvedValue(undefined),
    };
    const runner = new DatabaseJobRunner(
      jobs as never,
      {
        process: (job: any) => {
          signal = job.signal;
          return pending.promise;
        },
      } as never,
      {} as never,
      {} as never,
      health,
    );
    runner.onModuleInit();
    await jest.advanceTimersByTimeAsync(30_001);
    expect(signal?.aborted).toBe(true);
    pending.resolve({});
    await jest.advanceTimersByTimeAsync(1);
    expect(jobs.complete).not.toHaveBeenCalled();
    expect(jobs.fail).toHaveBeenCalledTimes(1);
    runner.onModuleDestroy();
  });

  it("readiness reports a sanitized failed or stalled worker even when database checks pass", async () => {
    const health = new BackgroundHealthService();
    health.register("jobWorker", 1000);
    const controller = new HealthController(
      {
        mockDataEnabled: false,
        $queryRaw: jest.fn().mockResolvedValue([]),
      } as never,
      { countRunnable: jest.fn().mockResolvedValue(0) } as never,
      health,
    );
    health.failure("jobWorker");
    let error = await controller.getReadiness().catch((e) => e);
    expect(error.getResponse().components.jobWorker).toEqual({
      status: "down",
      reason: "unavailable",
    });
    health.success("jobWorker");
    await jest.advanceTimersByTimeAsync(1001);
    error = await controller.getReadiness().catch((e) => e);
    expect(error.getResponse().components.jobWorker).toEqual({
      status: "down",
      reason: "stale",
    });
  });
});
