import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from "@nestjs/common";
import { PrismaService } from "../database/prisma.service";
import { InboxJobsService } from "./inbox-jobs.service";

@Injectable()
export class InboxScanScheduler implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(InboxScanScheduler.name);
  private timer?: NodeJS.Timeout;
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly inboxJobs: InboxJobsService,
  ) {}

  onModuleInit() {
    // PARTIAL accounts are lightweight continuation scans. Check frequently
    // so history keeps filling in without making the user wait on one job.
    this.timer = setInterval(() => void this.enqueueDueAccounts(), 15_000);
    this.timer.unref();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  private async enqueueDueAccounts() {
    if (this.running) return;
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
