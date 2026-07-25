import { Controller, Delete, Get, Query } from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { CurrentUser } from "../auth/current-user.decorator";
import { RequireRecentAuth } from "../auth/require-recent-auth.decorator";
import { ExportUserDataDto } from "./dto/export-user-data.dto";
import { UsersService } from "./users.service";

@Controller("users/me")
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get("export")
  @RequireRecentAuth()
  @Throttle({ default: { limit: 10, ttl: 60_000, blockDuration: 60_000 } })
  exportData(
    @CurrentUser("id") userId: string,
    @Query() query: ExportUserDataDto,
  ) {
    return this.usersService.exportData(userId, query);
  }

  @Delete()
  @RequireRecentAuth()
  @Throttle({ default: { limit: 2, ttl: 60_000, blockDuration: 300_000 } })
  deleteAccount(@CurrentUser("id") userId: string) {
    return this.usersService.deleteAccount(userId);
  }
}
