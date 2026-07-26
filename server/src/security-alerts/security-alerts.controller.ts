import { Controller, Get, Param, Patch, Query } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { Idempotent } from "../common/security/idempotent.decorator";
import { ListSecurityAlertsDto } from "./dto/list-security-alerts.dto";
import { SecurityAlertsService } from "./security-alerts.service";

@Controller("security-alerts")
export class SecurityAlertsController {
  constructor(private readonly securityAlertsService: SecurityAlertsService) {}

  @Get()
  list(
    @CurrentUser("id") userId: string,
    @Query() query: ListSecurityAlertsDto,
  ) {
    return this.securityAlertsService.list(userId, query);
  }

  @Get(":id")
  getById(@CurrentUser("id") userId: string, @Param("id") id: string) {
    return this.securityAlertsService.getById(userId, id);
  }

  @Patch(":id/resolve")
  @Idempotent("security-alert.resolve")
  resolve(@CurrentUser("id") userId: string, @Param("id") id: string) {
    return this.securityAlertsService.resolve(userId, id);
  }

  @Patch(":id/dismiss")
  @Idempotent("security-alert.dismiss")
  dismiss(@CurrentUser("id") userId: string, @Param("id") id: string) {
    return this.securityAlertsService.dismiss(userId, id);
  }
}
