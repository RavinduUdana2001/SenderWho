import { Controller, Delete, Get, Param, Post } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { RequireRecentAuth } from "../auth/require-recent-auth.decorator";
import { Throttle } from "@nestjs/throttler";
import { Idempotent } from "../common/security/idempotent.decorator";
import { EmailAccountsService } from "./email-accounts.service";

@Controller("email-accounts")
export class EmailAccountsController {
  constructor(private readonly emailAccountsService: EmailAccountsService) {}

  @Get()
  list(@CurrentUser("id") userId: string) {
    return this.emailAccountsService.listForCurrentUser(userId);
  }

  @Post(":id/sync")
  @Idempotent("email-account.sync")
  @Throttle({ default: { limit: 6, ttl: 60_000, blockDuration: 60_000 } })
  sync(@CurrentUser("id") userId: string, @Param("id") id: string) {
    return this.emailAccountsService.queueSync(userId, id);
  }

  @Delete(":id")
  @RequireRecentAuth()
  @Idempotent("email-account.disconnect")
  @Throttle({ default: { limit: 5, ttl: 60_000, blockDuration: 60_000 } })
  disconnect(@CurrentUser("id") userId: string, @Param("id") id: string) {
    return this.emailAccountsService.disconnect(userId, id);
  }
}
