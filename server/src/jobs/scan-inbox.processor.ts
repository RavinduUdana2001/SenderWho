import { Injectable, UnprocessableEntityException } from "@nestjs/common";
import { GmailSyncService } from "../providers/gmail/gmail-sync.service";
import { YahooSyncService } from "../providers/yahoo/yahoo-sync.service";
import { PrismaService } from "../database/prisma.service";
import { ProcessorJob } from "./database-job-queue.service";

@Injectable()
export class ScanInboxProcessor {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gmailSync: GmailSyncService,
    private readonly yahooSync: YahooSyncService,
  ) {}

  async process(job: ProcessorJob<{ emailAccountId: string }>) {
    const account = await this.prisma.emailAccount.findUniqueOrThrow({
      where: { id: job.data.emailAccountId },
      select: { provider: true },
    });
    const sync =
      account.provider === "GOOGLE"
        ? this.gmailSync.syncAccount.bind(this.gmailSync)
        : account.provider === "YAHOO"
          ? this.yahooSync.syncAccount.bind(this.yahooSync)
          : null;
    if (!sync) {
      throw new UnprocessableEntityException(
        `Mailbox provider ${account.provider} is not supported for scanning.`,
      );
    }
    const result = await sync(
      job.data.emailAccountId,
      (processed, discovered) => job.updateProgress({ processed, discovered }),
    );
    return { emailAccountId: job.data.emailAccountId, ...result };
  }
}
