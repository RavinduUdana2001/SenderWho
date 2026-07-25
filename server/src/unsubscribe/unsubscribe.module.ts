import { Module } from "@nestjs/common";
import { QueuesModule } from "../jobs/queues.module";
import { UnsubscribeController } from "./unsubscribe.controller";
import { UnsubscribeService } from "./unsubscribe.service";

@Module({
  imports: [QueuesModule],
  controllers: [UnsubscribeController],
  providers: [UnsubscribeService],
})
export class UnsubscribeModule {}
