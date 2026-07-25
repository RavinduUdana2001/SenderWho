import { Controller, Get } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { SettingsService } from "../settings/settings.service";

@Controller("privacy-security")
export class PrivacySecurityController {
  constructor(private readonly settingsService: SettingsService) {}

  @Get()
  getPrivacySecurity(@CurrentUser("id") userId: string) {
    return this.settingsService.getPrivacySecurity(userId);
  }
}
