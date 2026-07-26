import { Body, Controller, Get, Param, Post } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { Throttle } from "@nestjs/throttler";
import { Idempotent } from "../common/security/idempotent.decorator";
import { CleanupService } from "./cleanup.service";
import { CreateCleanupJobDto } from "./dto/create-cleanup-job.dto";
import { PreviewCleanupDto } from "./dto/preview-cleanup.dto";

@Controller("cleanup")
export class CleanupController {
  constructor(private readonly cleanupService: CleanupService) {}

  @Get("suggestions")
  getSuggestions(@CurrentUser("id") userId: string) {
    return this.cleanupService.getSuggestions(userId);
  }

  @Post("jobs")
  @Idempotent("cleanup.create")
  @Throttle({ default: { limit: 5, ttl: 60_000, blockDuration: 120_000 } })
  createJob(
    @CurrentUser("id") userId: string,
    @Body() body: CreateCleanupJobDto,
  ) {
    return this.cleanupService.createJob(userId, body);
  }

  @Post("preview")
  @Throttle({ default: { limit: 30, ttl: 60_000, blockDuration: 60_000 } })
  preview(@CurrentUser("id") userId: string, @Body() body: PreviewCleanupDto) {
    return this.cleanupService.preview(userId, body);
  }

  @Get("jobs")
  getActiveJobs(@CurrentUser("id") userId: string) {
    return this.cleanupService.getActiveJobs(userId);
  }

  @Get("jobs/:id")
  getJob(@CurrentUser("id") userId: string, @Param("id") id: string) {
    return this.cleanupService.getJob(userId, id);
  }
}
