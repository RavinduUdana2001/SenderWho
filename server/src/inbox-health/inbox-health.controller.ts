import { Controller, Get } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { InboxHealthService } from "./inbox-health.service";

@Controller("inbox-health")
export class InboxHealthController {
  constructor(private readonly inboxHealthService: InboxHealthService) {}

  @Get()
  getHealth(@CurrentUser("id") userId: string) {
    return this.inboxHealthService.getHealth(userId);
  }
}
