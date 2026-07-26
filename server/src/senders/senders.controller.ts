import { Body, Controller, Get, Param, Patch, Query } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { Throttle } from "@nestjs/throttler";
import { Idempotent } from "../common/security/idempotent.decorator";
import { ListSendersDto } from "./dto/list-senders.dto";
import { SendersService } from "./senders.service";
import { SenderBlockDto, SenderTrustDto } from "./dto/sender-control.dto";

@Controller("senders")
export class SendersController {
  constructor(private readonly sendersService: SendersService) {}

  @Get()
  list(@CurrentUser("id") userId: string, @Query() query: ListSendersDto) {
    return this.sendersService.list(userId, query);
  }

  @Get("top")
  getTopSenders(@CurrentUser("id") userId: string) {
    return this.sendersService.getTopSenders(userId);
  }

  @Get(":id")
  getById(@CurrentUser("id") userId: string, @Param("id") id: string) {
    return this.sendersService.getById(userId, id);
  }

  @Patch(":id/block")
  @Idempotent("sender.block")
  @Throttle({ default: { limit: 15, ttl: 60_000, blockDuration: 60_000 } })
  block(
    @CurrentUser("id") userId: string,
    @Param("id") id: string,
    @Body() body: SenderBlockDto,
  ) {
    return this.sendersService.setBlocked(userId, id, body.blocked ?? true);
  }

  @Patch(":id/trust")
  @Idempotent("sender.trust")
  @Throttle({ default: { limit: 15, ttl: 60_000, blockDuration: 60_000 } })
  trust(
    @CurrentUser("id") userId: string,
    @Param("id") id: string,
    @Body() body: SenderTrustDto,
  ) {
    return this.sendersService.setTrusted(userId, id, body.trusted ?? true);
  }
}
