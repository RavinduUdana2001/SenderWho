import { Module } from "@nestjs/common";
import { SecurityAlertsController } from "./security-alerts.controller";
import { SecurityAlertsService } from "./security-alerts.service";

@Module({
  controllers: [SecurityAlertsController],
  providers: [SecurityAlertsService],
})
export class SecurityAlertsModule {}
