import { Module } from "@nestjs/common";
import { CleanupProcessor } from "./cleanup.processor";
import { DatabaseJobQueueService } from "./database-job-queue.service";
import { DatabaseJobRunner } from "./database-job-runner.service";
import { InboxScanScheduler } from "./inbox-scan.scheduler";
import { InboxJobsService } from "./inbox-jobs.service";
import { ScanInboxProcessor } from "./scan-inbox.processor";
import { UnsubscribeProcessor } from "./unsubscribe.processor";

const mockDataEnabled = process.env.MOCK_DATA_ENABLED === "true";

@Module({
  providers: [
    DatabaseJobQueueService,
    InboxJobsService,
    ScanInboxProcessor,
    CleanupProcessor,
    UnsubscribeProcessor,
    ...(mockDataEnabled ? [] : [DatabaseJobRunner, InboxScanScheduler]),
  ],
  exports: [DatabaseJobQueueService, InboxJobsService],
})
export class QueuesModule {}
