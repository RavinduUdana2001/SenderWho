import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { PrismaService } from "../database/prisma.service";

@Injectable()
export class DataRetentionService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DataRetentionService.name);
  private timer?: NodeJS.Timeout;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  onModuleInit() {
    if (this.prisma.mockDataEnabled) return;
    this.timer = setInterval(() => void this.run(), 24 * 60 * 60 * 1_000);
    this.timer.unref();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  async run() {
    const messageDays = this.config.get<number>("retention.messageDays", 365);
    const auditDays = this.config.get<number>("retention.auditDays", 730);
    const jobDays = this.config.get<number>("retention.jobDays", 90);
    const now = Date.now();
    const messageCutoff = new Date(now - messageDays * 24 * 60 * 60 * 1_000);
    const auditCutoff = new Date(now - auditDays * 24 * 60 * 60 * 1_000);
    const jobCutoff = new Date(now - jobDays * 24 * 60 * 60 * 1_000);
    const sessionCutoff = new Date(now - 30 * 24 * 60 * 60 * 1_000);

    const results = await this.prisma.$transaction([
      this.prisma.oAuthLoginSession.deleteMany({
        where: { expiresAt: { lt: new Date() } },
      }),
      this.prisma.appSession.deleteMany({
        where: {
          OR: [
            { expiresAt: { lt: new Date() } },
            { revokedAt: { lt: sessionCutoff } },
          ],
        },
      }),
      this.prisma.idempotencyRecord.deleteMany({
        where: { expiresAt: { lt: new Date() } },
      }),
      this.prisma.message.deleteMany({
        where: { receivedAt: { lt: messageCutoff } },
      }),
      this.prisma.auditLog.deleteMany({
        where: { createdAt: { lt: auditCutoff } },
      }),
      this.prisma.cleanupJob.deleteMany({
        where: { completedAt: { lt: jobCutoff } },
      }),
      this.prisma.unsubscribeJob.deleteMany({
        where: { completedAt: { lt: jobCutoff } },
      }),
      this.prisma.backgroundJob.deleteMany({
        where: {
          completedAt: { lt: jobCutoff },
          status: { in: ["COMPLETED", "FAILED", "CANCELED"] },
        },
      }),
      this.prisma.apiRateLimit.deleteMany({
        where: {
          expiresAt: { lt: new Date() },
          OR: [{ blockedUntil: null }, { blockedUntil: { lt: new Date() } }],
        },
      }),
    ]);
    this.logger.log(
      JSON.stringify({
        event: "data_retention.completed",
        deletedByTable: results.map((result) => result.count),
      }),
    );
  }
}
