import { Module } from "@nestjs/common";
import { SettingsModule } from "../settings/settings.module";
import { PrivacySecurityController } from "./privacy-security.controller";

@Module({
  imports: [SettingsModule],
  controllers: [PrivacySecurityController],
})
export class PrivacySecurityModule {}
