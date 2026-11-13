import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from "@nestjs/common";
import { BackgroundHealthService } from "../common/background-health.service";
import { PrismaService } from "../database/prisma.service";
import { InboxJobsService } from "./inbox-jobs.service";

@Injectable()
export class InboxScanScheduler implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(InboxScanScheduler.name);
  private timer?: NodeJS.Timeout;
  private running = false;
  private failures = 0;
  private retryAt = 0;

  constructor(
    private readonly prisma: PrismaService,
    private readonly inboxJobs: InboxJobsService,
    private readonly health: BackgroundHealthService = new BackgroundHealthService(),
  ) {}

  onModuleInit() {
    this.health.register("scanScheduler", 90_000);
    // PARTIAL accounts are lightweight continuation scans. Check frequently
    // so history keeps filling in without making the user wait on one job.
    this.timer = setInterval(() => void this.enqueueDueAccounts(), 15_000);
    this.timer.unref();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
    this.health.remove("scanScheduler");
  }

  private async enqueueDueAccounts() {
    if (this.running || Date.now() < this.retryAt) return;
    this.running = true;
    try {
      const accounts = await this.prisma.emailAccount.findMany({
        // FAILED accounts require an explicit retry from the user. Scheduling
        // them every minute creates a retry storm for permanent provider
        // errors such as a disabled OAuth client or revoked grant.
        where: { syncStatus: { in: ["PENDING", "PARTIAL", "READY"] } },
        select: {
          id: true,
          syncStatus: true,
          lastSyncedAt: true,
          user: {
            select: {
              settings: { select: { inboxScanFrequency: true } },
            },
          },
        },
      });
      const now = Date.now();
      let enqueueFailed = false;
      for (const account of accounts) {
        const frequency = account.user.settings?.inboxScanFrequency ?? "Auto";
        const interval = this.intervalFor(frequency);
        if (interval == null && account.syncStatus !== "PARTIAL") continue;
        const lastSync = account.lastSyncedAt?.getTime() ?? 0;
        if (
          account.syncStatus !== "PARTIAL" &&
          interval != null &&
          now - lastSync < interval
        ) {
          continue;
        }
        try {
          await this.inboxJobs.enqueueScan(account.id);
        } catch (error) {
          enqueueFailed = true;
          this.logger.warn(
            JSON.stringify({
              event: "gmail.sync.enqueue_failed",
              targetId: account.id,
              errorType:
                error instanceof Error
                  ? error.constructor.name
                  : "UnknownError",
            }),
          );
        }
      }
      if (enqueueFailed) throw new Error("Scan scheduling was incomplete");
      this.failures = 0;
      this.retryAt = 0;
      this.health.success("scanScheduler");
    } catch (error) {
      this.health.failure("scanScheduler");
      this.retryAt =
        Date.now() +
        Math.min(15_000 * 2 ** Math.min(this.failures++, 4), 60_000);
      this.logger.error(
        JSON.stringify({
          event: "scan_scheduler.failed",
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
    } finally {
      this.running = false;
    }
  }

  private intervalFor(frequency: string) {
    switch (frequency) {
      case "Manual":
        return null;
      case "Daily":
        return 24 * 60 * 60 * 1_000;
      case "Hourly":
        return 60 * 60 * 1_000;
      case "Auto":
      default:
        return 15 * 60 * 1_000;
    }
  }
}
