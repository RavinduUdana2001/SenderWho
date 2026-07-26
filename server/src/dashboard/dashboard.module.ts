import { Module } from "@nestjs/common";
import { InboxHealthModule } from "../inbox-health/inbox-health.module";
import { DashboardController } from "./dashboard.controller";
import { DashboardService } from "./dashboard.service";

@Module({
  imports: [InboxHealthModule],
  controllers: [DashboardController],
  providers: [DashboardService],
})
export class DashboardModule {}
