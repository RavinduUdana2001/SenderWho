import { Body, Controller, Get, Param, Post } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { Throttle } from "@nestjs/throttler";
import { Idempotent } from "../common/security/idempotent.decorator";
import { CreateUnsubscribeJobDto } from "./dto/create-unsubscribe-job.dto";
import { CreateUnsubscribeJobsDto } from "./dto/create-unsubscribe-jobs.dto";
import { ListUnsubscribeJobStatusDto } from "./dto/list-unsubscribe-job-status.dto";
import { UnsubscribeService } from "./unsubscribe.service";

@Controller("unsubscribe")
export class UnsubscribeController {
  constructor(private readonly unsubscribeService: UnsubscribeService) {}

  @Get("candidates")
  getCandidates(@CurrentUser("id") userId: string) {
    return this.unsubscribeService.getCandidates(userId);
  }

  @Post("jobs")
  @Idempotent("unsubscribe.create")
  @Throttle({ default: { limit: 10, ttl: 60_000, blockDuration: 120_000 } })
  createJob(
    @CurrentUser("id") userId: string,
    @Body() body: CreateUnsubscribeJobDto,
  ) {
    return this.unsubscribeService.createJob(userId, body.senderId);
  }

  @Post("jobs/batch")
  @Idempotent("unsubscribe.create-batch")
  @Throttle({ default: { limit: 3, ttl: 60_000, blockDuration: 120_000 } })
  createJobs(
    @CurrentUser("id") userId: string,
    @Body() body: CreateUnsubscribeJobsDto,
  ) {
    return this.unsubscribeService.createJobs(userId, body.senderIds);
  }

  @Get("jobs")
  getActiveJobs(@CurrentUser("id") userId: string) {
    return this.unsubscribeService.getActiveJobs(userId);
  }

  @Post("jobs/status")
  @Throttle({ default: { limit: 30, ttl: 60_000, blockDuration: 15_000 } })
  getJobStatuses(
    @CurrentUser("id") userId: string,
    @Body() body: ListUnsubscribeJobStatusDto,
  ) {
    return this.unsubscribeService.getJobs(userId, body.jobIds);
  }

  @Get("jobs/:id")
  getJob(@CurrentUser("id") userId: string, @Param("id") id: string) {
    return this.unsubscribeService.getJob(userId, id);
  }
}
