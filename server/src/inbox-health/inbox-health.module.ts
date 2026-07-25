import { Module } from "@nestjs/common";
import { InboxHealthController } from "./inbox-health.controller";
import { InboxHealthService } from "./inbox-health.service";

@Module({
  controllers: [InboxHealthController],
  providers: [InboxHealthService],
})
export class InboxHealthModule {}
