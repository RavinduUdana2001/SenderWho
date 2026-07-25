import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from "@nestjs/common";
import { PrismaService } from "../database/prisma.service";
import { InboxJobsService } from "../jobs/inbox-jobs.service";
import { EmailProvider, JobStatus, SyncStatus } from "@prisma/client";
import {
  TokenEncryptionService,
  googleProviderTokenContext,
} from "../common/security/token-encryption.service";
import { getGoogleAccountRecoveryAction } from "../providers/google-account-recovery";

@Injectable()
export class EmailAccountsService {
  private readonly logger = new Logger(EmailAccountsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly inboxJobs: InboxJobsService,
    private readonly encryption: TokenEncryptionService,
  ) {}

  async listForCurrentUser(userId: string) {
    if (this.prisma.mockDataEnabled) {
      return {
        items: [
          {
            id: "demo_gmail",
            provider: "GOOGLE",
            emailAddress: "senderwho.demo@gmail.com",
            displayName: "Demo Gmail",
            syncStatus: "READY",
            lastSyncedAt: new Date().toISOString(),
            createdAt: new Date().toISOString(),
          },
        ],
      };
    }

    const accounts = await this.prisma.emailAccount.findMany({
      where: { userId },
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        provider: true,
        emailAddress: true,
        displayName: true,
        syncStatus: true,
        lastSyncedAt: true,
        lastSyncError: true,
        syncStartedAt: true,
        backfillComplete: true,
        backfillProcessed: true,
        createdAt: true,
      },
    });

    return {
      items: accounts.map((account) => ({
        ...account,
        recoveryAction: getGoogleAccountRecoveryAction(
          account.syncStatus,
          account.lastSyncError,
        ),
      })),
    };
  }

  async queueSync(userId: string, id: string) {
    const account = await this.prisma.emailAccount.findFirst({
      where: { id, userId },
      select: { id: true, provider: true, syncStatus: true },
    });
    if (!account) throw new NotFoundException("Email account was not found.");
    if (account.syncStatus === SyncStatus.DISCONNECTED) {
      throw new BadRequestException(
        "Reconnect this Gmail account before starting a scan.",
      );
    }
    await this.prisma.emailAccount.update({
      where: { id: account.id },
      data: { syncStatus: SyncStatus.PENDING, lastSyncError: null },
    });
    let job;
    try {
      job = await this.inboxJobs.enqueueScan(account.id);
    } catch {
      await this.prisma.emailAccount.update({
        where: { id: account.id },
        data: {
          syncStatus: SyncStatus.FAILED,
          lastSyncError: "The Gmail scan could not be queued.",
        },
      });
      throw new ServiceUnavailableException(
        "The Gmail scan could not be queued. Please retry.",
      );
    }
    try {
      await this.prisma.auditLog.create({
        data: {
          userId,
          action: "email_account.sync_queued",
          targetType: "EmailAccount",
          targetId: account.id,
        },
      });
    } catch (error) {
      this.logger.error(
        JSON.stringify({
          event: "email_account.sync_audit.failed",
          targetId: account.id,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
    }
    return { emailAccountId: account.id, queue: "scan-inbox", ...job };
  }

  async disconnect(userId: string, id: string) {
    if (this.prisma.mockDataEnabled && id === "demo_gmail") {
      return {
        id,
        syncStatus: "DISCONNECTED",
      };
    }

    const account = await this.prisma.emailAccount.findFirst({
      where: { id, userId },
      select: {
        id: true,
        provider: true,
        providerAccountId: true,
        refreshTokenEncrypted: true,
        accessTokenEncrypted: true,
      },
    });
    if (!account) throw new NotFoundException("Email account was not found.");
    const encryptedToken =
      account.refreshTokenEncrypted ?? account.accessTokenEncrypted;
    const disconnectedAt = new Date();
    const [updated] = await this.prisma.$transaction([
      this.prisma.emailAccount.update({
        where: { id: account.id },
        data: {
          syncStatus: SyncStatus.DISCONNECTED,
          syncStartedAt: null,
          accessTokenEncrypted: null,
          refreshTokenEncrypted: null,
        },
      }),
      this.prisma.cleanupJob.updateMany({
        where: {
          userId,
          emailAccountId: account.id,
          status: { in: [JobStatus.QUEUED, JobStatus.RUNNING] },
        },
        data: {
          status: JobStatus.CANCELED,
          completedAt: disconnectedAt,
          activeKey: null,
        },
      }),
      this.prisma.unsubscribeJob.updateMany({
        where: {
          userId,
          status: { in: [JobStatus.QUEUED, JobStatus.RUNNING] },
          sender: { emailAccountId: account.id },
        },
        data: {
          status: JobStatus.CANCELED,
          completedAt: disconnectedAt,
        },
      }),
    ]);
    let providerRevoked = false;
    if (encryptedToken && account.provider === EmailProvider.GOOGLE) {
      try {
        const response = await fetch("https://oauth2.googleapis.com/revoke", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            token: this.encryption.decrypt(
              encryptedToken,
              googleProviderTokenContext(account.providerAccountId),
            ),
          }),
          signal: AbortSignal.timeout(15_000),
        });
        providerRevoked = response.ok;
        await response.body?.cancel();
      } catch (error) {
        this.logger.warn(
          JSON.stringify({
            event: "google.token_revocation.failed",
            targetId: account.id,
            errorType:
              error instanceof Error ? error.constructor.name : "UnknownError",
          }),
        );
      }
    }
    try {
      await this.prisma.auditLog.create({
        data: {
          userId,
          action: "email_account.disconnected",
          targetType: "EmailAccount",
          targetId: account.id,
          metadata: { providerRevoked },
        },
      });
    } catch (error) {
      this.logger.error(
        JSON.stringify({
          event: "email_account.disconnect_audit.failed",
          targetId: account.id,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
    }
    return { ...updated, providerRevoked };
  }
}
