import { Injectable, Logger } from "@nestjs/common";
import { PrismaService } from "../database/prisma.service";
import { UpdatePreferencesDto } from "./dto/update-preferences.dto";

@Injectable()
export class SettingsService {
  private readonly logger = new Logger(SettingsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async getSettings(userId: string) {
    const [
      settings,
      connectedAccountsCount,
      archivedEmails,
      trashEmails,
      blockedSenders,
    ] = await Promise.all([
      this.ensureSettings(userId),
      this.prisma.emailAccount.count({
        where: { userId, syncStatus: { not: "DISCONNECTED" } },
      }),
      this.prisma.message.count({
        where: { userId, isArchived: true, isTrashed: false },
      }),
      this.prisma.message.count({ where: { userId, isTrashed: true } }),
      this.prisma.sender.count({ where: { userId, isBlocked: true } }),
    ]);

    return {
      account: { connectedAccountsCount },
      preferences: {
        notificationsEnabled: settings.notificationsEnabled,
        inboxScanFrequency: settings.inboxScanFrequency,
        theme: settings.theme,
      },
      emailManagement: { archivedEmails, trashEmails, blockedSenders },
    };
  }

  async updatePreferences(userId: string, body: UpdatePreferencesDto) {
    await this.ensureSettings(userId);
    await this.prisma.userSettings.update({
      where: { userId },
      data: body,
    });
    try {
      await this.prisma.auditLog.create({
        data: {
          userId,
          action: "settings.preferences.updated",
          targetType: "UserSettings",
          targetId: userId,
          metadata: { changedFields: Object.keys(body).sort() },
        },
      });
    } catch (error) {
      this.logger.error(
        JSON.stringify({
          event: "settings.audit.failed",
          targetId: userId,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
    }
    return this.getSettings(userId);
  }

  async getPrivacySecurity(userId: string) {
    const [settings, blockedSenders, trustedSenders, activeSessions] =
      await Promise.all([
        this.ensureSettings(userId),
        this.prisma.sender.count({ where: { userId, isBlocked: true } }),
        this.prisma.sender.count({ where: { userId, isTrusted: true } }),
        this.prisma.appSession.count({
          where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
        }),
      ]);
    return {
      twoFactorEnabled: settings.twoFactorEnabled,
      blockedSenders,
      trustedSenders,
      activeSessions,
      dataRetention: settings.dataRetention,
      privacyMode: settings.privacyMode,
    };
  }

  private ensureSettings(userId: string) {
    return this.prisma.userSettings.upsert({
      where: { userId },
      create: { userId },
      update: {},
    });
  }
}
