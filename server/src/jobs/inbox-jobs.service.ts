import { Injectable } from "@nestjs/common";
import { DatabaseJobQueueService } from "./database-job-queue.service";

@Injectable()
export class InboxJobsService {
  constructor(private readonly jobs: DatabaseJobQueueService) {}

  async enqueueScan(emailAccountId: string) {
    const job = await this.jobs.add(
      "scan-inbox",
      "sync-gmail-account",
      { emailAccountId },
      {
        deduplication: { id: `scan-${emailAccountId}` },
        attempts: 4,
        backoff: { type: "exponential", delay: 2_000 },
        removeOnComplete: { count: 500, age: 24 * 60 * 60 },
        removeOnFail: { count: 1_000, age: 7 * 24 * 60 * 60 },
      },
    );

    return { jobId: job.id, status: "QUEUED" as const };
  }
}
