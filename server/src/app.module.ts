import { Module } from "@nestjs/common";
import { APP_INTERCEPTOR } from "@nestjs/core";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { ThrottlerModule, ThrottlerStorageService } from "@nestjs/throttler";
import { ActivityModule } from "./activity/activity.module";
import configuration from "./common/config/configuration";
import { validateEnvironment } from "./common/config/validate-environment";
import { AuthModule } from "./auth/auth.module";
import { CategoriesModule } from "./categories/categories.module";
import { CleanupModule } from "./cleanup/cleanup.module";
import { DashboardModule } from "./dashboard/dashboard.module";
import { DatabaseModule } from "./database/database.module";
import { EmailAccountsModule } from "./email-accounts/email-accounts.module";
import { EmailMessagesModule } from "./email-messages/email-messages.module";
import { HealthController } from "./health.controller";
import { InboxHealthModule } from "./inbox-health/inbox-health.module";
import { QueuesModule } from "./jobs/queues.module";
import { PrivacySecurityModule } from "./privacy-security/privacy-security.module";
import { EmailProvidersModule } from "./providers/email-providers.module";
import { SearchModule } from "./search/search.module";
import { SecurityAlertsModule } from "./security-alerts/security-alerts.module";
import { SendersModule } from "./senders/senders.module";
import { SettingsModule } from "./settings/settings.module";
import { UnsubscribeModule } from "./unsubscribe/unsubscribe.module";
import { UsersModule } from "./users/users.module";
import { MysqlThrottlerStorage } from "./common/security/mysql-throttler.storage";
import { PrismaService } from "./database/prisma.service";
import { IdempotencyInterceptor } from "./common/security/idempotency.interceptor";
import { SecurityLoggingInterceptor } from "./common/security/security-logging.interceptor";
import { PublicSiteModule } from "./public-site/public-site.module";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      validate: validateEnvironment,
      envFilePath: [".env.local", ".env"],
    }),
    ThrottlerModule.forRootAsync({
      imports: [DatabaseModule],
      inject: [ConfigService, PrismaService],
      useFactory: (config: ConfigService, prisma: PrismaService) => {
        const storage = config.get<boolean>("mockDataEnabled", false)
          ? new ThrottlerStorageService()
          : new MysqlThrottlerStorage(prisma);
        return {
          storage,
          getTracker: (request: Record<string, any>) => {
            const ip = String(request.ip ?? "unknown");
            const user = String(request.user?.id ?? "anonymous");
            const session = String(request.user?.sessionId ?? "no-session");
            return user === "anonymous"
              ? `${ip}:anonymous`
              : `${ip}:${user}:${session}`;
          },
          throttlers: [{ name: "default", ttl: 60_000, limit: 120 }],
        };
      },
    }),
    DatabaseModule,
    EmailProvidersModule,
    QueuesModule,
    AuthModule,
    UsersModule,
    EmailAccountsModule,
    EmailMessagesModule,
    DashboardModule,
    ActivityModule,
    SendersModule,
    CategoriesModule,
    SearchModule,
    InboxHealthModule,
    SecurityAlertsModule,
    SettingsModule,
    PrivacySecurityModule,
    CleanupModule,
    UnsubscribeModule,
    PublicSiteModule,
  ],
  controllers: [HealthController],
  providers: [
    { provide: APP_INTERCEPTOR, useClass: SecurityLoggingInterceptor },
    { provide: APP_INTERCEPTOR, useClass: IdempotencyInterceptor },
  ],
})
export class AppModule {}
