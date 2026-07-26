import { Body, Controller, Get, Param, Post, Query } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { Throttle } from "@nestjs/throttler";
import { Idempotent } from "../common/security/idempotent.decorator";
import { BulkMessageActionDto } from "./dto/bulk-message-action.dto";
import { ListMessagesDto } from "./dto/list-messages.dto";
import { MessageReadStateDto } from "./dto/message-read-state.dto";
import { EmailMessagesService } from "./email-messages.service";

@Controller("emails")
export class EmailMessagesController {
  constructor(private readonly emailMessagesService: EmailMessagesService) {}

  @Get()
  list(@CurrentUser("id") userId: string, @Query() query: ListMessagesDto) {
    return this.emailMessagesService.list(userId, query);
  }

  @Get("promotions")
  getPromotionEmails(@CurrentUser("id") userId: string) {
    return this.emailMessagesService.getPromotionEmails(userId);
  }

  @Get(":id/thread")
  getThread(@CurrentUser("id") userId: string, @Param("id") id: string) {
    return this.emailMessagesService.getThread(userId, id);
  }

  @Get(":id/content")
  getContent(@CurrentUser("id") userId: string, @Param("id") id: string) {
    return this.emailMessagesService.getContent(userId, id);
  }

  @Get(":id")
  getById(@CurrentUser("id") userId: string, @Param("id") id: string) {
    return this.emailMessagesService.getById(userId, id);
  }

  @Post("actions/read-state")
  @Idempotent("email.read-state")
  @Throttle({ default: { limit: 30, ttl: 60_000, blockDuration: 60_000 } })
  setReadState(
    @CurrentUser("id") userId: string,
    @Body() body: MessageReadStateDto,
  ) {
    return this.emailMessagesService.setReadState(
      userId,
      body.messageIds,
      body.isRead,
    );
  }

  @Post("actions/archive")
  @Idempotent("email.archive")
  @Throttle({ default: { limit: 20, ttl: 60_000, blockDuration: 60_000 } })
  archive(
    @CurrentUser("id") userId: string,
    @Body() body: BulkMessageActionDto,
  ) {
    return this.emailMessagesService.archive(userId, body.messageIds);
  }

  @Post("actions/unarchive")
  @Idempotent("email.unarchive")
  @Throttle({ default: { limit: 20, ttl: 60_000, blockDuration: 60_000 } })
  unarchive(
    @CurrentUser("id") userId: string,
    @Body() body: BulkMessageActionDto,
  ) {
    return this.emailMessagesService.unarchive(userId, body.messageIds);
  }

  @Post("actions/trash")
  @Idempotent("email.trash")
  @Throttle({ default: { limit: 10, ttl: 60_000, blockDuration: 120_000 } })
  trash(@CurrentUser("id") userId: string, @Body() body: BulkMessageActionDto) {
    return this.emailMessagesService.trash(userId, body.messageIds);
  }

  @Post("actions/restore")
  @Idempotent("email.restore")
  @Throttle({ default: { limit: 20, ttl: 60_000, blockDuration: 60_000 } })
  restore(
    @CurrentUser("id") userId: string,
    @Body() body: BulkMessageActionDto,
  ) {
    return this.emailMessagesService.restore(userId, body.messageIds);
  }
}
