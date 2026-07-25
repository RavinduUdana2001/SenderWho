import { Module } from "@nestjs/common";
import { CleanupController } from "./cleanup.controller";
import { CleanupService } from "./cleanup.service";
import { QueuesModule } from "../jobs/queues.module";

@Module({
  imports: [QueuesModule],
  controllers: [CleanupController],
  providers: [CleanupService],
})
export class CleanupModule {}
