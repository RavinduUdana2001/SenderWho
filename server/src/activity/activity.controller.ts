import { Controller, Get } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { ActivityService } from "./activity.service";

@Controller("activity")
export class ActivityController {
  constructor(private readonly activityService: ActivityService) {}

  @Get()
  getInsights(@CurrentUser("id") userId: string) {
    return this.activityService.getInsights(userId);
  }
}
