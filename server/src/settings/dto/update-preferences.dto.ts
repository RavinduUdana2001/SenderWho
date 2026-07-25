import { IsBoolean, IsIn, IsOptional } from "class-validator";

export class UpdatePreferencesDto {
  @IsOptional()
  @IsBoolean()
  notificationsEnabled?: boolean;

  @IsOptional()
  @IsIn(["Manual", "Hourly", "Daily", "Auto"])
  inboxScanFrequency?: string;

  @IsOptional()
  @IsIn(["System", "Light", "Dark"])
  theme?: string;
}
