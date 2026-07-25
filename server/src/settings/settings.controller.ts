import { Body, Controller, Get, Patch } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { SettingsService } from "./settings.service";
import { UpdatePreferencesDto } from "./dto/update-preferences.dto";
import { Idempotent } from "../common/security/idempotent.decorator";

@Controller("settings")
export class SettingsController {
  constructor(private readonly settingsService: SettingsService) {}

  @Get()
  getSettings(@CurrentUser("id") userId: string) {
    return this.settingsService.getSettings(userId);
  }

  @Patch("preferences")
  @Idempotent("settings.preferences")
  updatePreferences(
    @CurrentUser("id") userId: string,
    @Body() body: UpdatePreferencesDto,
  ) {
    return this.settingsService.updatePreferences(userId, body);
  }
}
