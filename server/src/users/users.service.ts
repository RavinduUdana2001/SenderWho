import { Injectable, Logger, NotFoundException } from "@nestjs/common";
import { EmailProvider, JobStatus, SyncStatus } from "@prisma/client";
import {
  TokenEncryptionService,
  googleProviderTokenContext,
} from "../common/security/token-encryption.service";
import { PrismaService } from "../database/prisma.service";
import { ExportUserDataDto } from "./dto/export-user-data.dto";

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly encryption: TokenEncryptionService,
  ) {}

  findById(id: string) {
    return this.prisma.user.findFirst({ where: { id, deletedAt: null } });
  }

  async exportData(userId: string, query: ExportUserDataDto) {
    await this.prisma.auditLog.create({
      data: {
        userId,
        action: "privacy.export.requested",
        targetType: "User",
        targetId: userId,
        metadata: { section: query.section, page: query.page },
      },
    });
    const skip = (query.page - 1) * query.limit;
    const page = { skip, take: query.limit };
    switch (query.section) {
      case "profile": {
        const item = await this.prisma.user.findFirst({
          where: { id: userId, deletedAt: null },
          select: {
            id: true,
            email: true,
            displayName: true,
            createdAt: true,
            updatedAt: true,
            settings: true,
          },
        });
        if (!item) throw new NotFoundException("User account was not found.");
        return { section: query.section, items: [item], hasMore: false };
      }
      case "accounts": {
        const items = await this.prisma.emailAccount.findMany({
          where: { userId },
          ...page,
          select: {
            id: true,
            provider: true,
            emailAddress: true,
            displayName: true,
            scopes: true,
            syncStatus: true,
            lastSyncedAt: true,
            createdAt: true,
          },
        });
        return this.exportPage(query, items);
      }
      case "senders": {
        const items = await this.prisma.sender.findMany({
          where: { userId },
          ...page,
          orderBy: { createdAt: "asc" },
        });
        return this.exportPage(query, items);
      }
      case "messages": {
        const items = await this.prisma.message.findMany({
          where: { userId },
          ...page,
          orderBy: { createdAt: "asc" },
        });
        return this.exportPage(query, items);
      }
      case "alerts": {
        const items = await this.prisma.securityAlert.findMany({
          where: { userId },
          ...page,
          orderBy: { detectedAt: "asc" },
        });
        return this.exportPage(query, items);
      }
      case "audit": {
        const items = await this.prisma.auditLog.findMany({
          where: { userId },
          ...page,
          orderBy: { createdAt: "asc" },
          select: {
            id: true,
            action: true,
            targetType: true,
            targetId: true,
            createdAt: true,
          },
        });
        return this.exportPage(query, items);
      }
    }
  }

  async deleteAccount(userId: string) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, deletedAt: null },
      include: {
        emailAccounts: {
          select: {
            refreshTokenEncrypted: true,
            accessTokenEncrypted: true,
            provider: true,
            providerAccountId: true,
          },
        },
      },
    });
    if (!user) throw new NotFoundException("User account was not found.");

    const deletionStartedAt = new Date();
    await this.prisma.$transaction([
      this.prisma.emailAccount.updateMany({
        where: { userId },
        data: {
          syncStatus: SyncStatus.DISCONNECTED,
          syncStartedAt: null,
        },
      }),
      this.prisma.cleanupJob.updateMany({
        where: {
          userId,
          status: { in: [JobStatus.QUEUED, JobStatus.RUNNING] },
        },
        data: {
          status: JobStatus.CANCELED,
          completedAt: deletionStartedAt,
          activeKey: null,
        },
      }),
      this.prisma.unsubscribeJob.updateMany({
        where: {
          userId,
          status: { in: [JobStatus.QUEUED, JobStatus.RUNNING] },
        },
        data: {
          status: JobStatus.CANCELED,
          completedAt: deletionStartedAt,
        },
      }),
      this.prisma.appSession.updateMany({
        where: { userId, revokedAt: null },
        data: {
          revokedAt: deletionStartedAt,
          revocationReason: "USER_DELETION",
        },
      }),
    ]);

    let providerRevocationsAttempted = 0;
    let providerRevocationsSucceeded = 0;
    for (const account of user.emailAccounts) {
      // Yahoo currently documents user-managed grant revocation through Yahoo
      // Account Security, but not an application token-revocation endpoint.
      // Never submit a Yahoo token to Google's revocation endpoint.
      if (account.provider !== EmailProvider.GOOGLE) continue;
      const encrypted =
        account.refreshTokenEncrypted ?? account.accessTokenEncrypted;
      if (!encrypted) continue;
      providerRevocationsAttempted += 1;
      try {
        const response = await fetch("https://oauth2.googleapis.com/revoke", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            token: this.encryption.decrypt(
              encrypted,
              googleProviderTokenContext(account.providerAccountId),
            ),
          }),
          signal: AbortSignal.timeout(15_000),
        });
        if (response.ok) providerRevocationsSucceeded += 1;
        await response.body?.cancel();
      } catch {
        // Local deletion must still complete; Google also provides a user-facing
        // grant revocation path if the provider endpoint is unavailable.
      }
    }

    await this.prisma.$transaction([
      this.prisma.auditLog.deleteMany({ where: { userId } }),
      this.prisma.user.delete({ where: { id: userId } }),
    ]);
    this.logger.warn(
      JSON.stringify({
        event: "privacy.account.deleted",
        actorUserId: userId,
        providerRevocationsAttempted,
        providerRevocationsSucceeded,
      }),
    );
    return {
      success: true,
      providerRevocationsAttempted,
      providerRevocationsSucceeded,
    };
  }

  private exportPage<T>(query: ExportUserDataDto, items: T[]) {
    return {
      section: query.section,
      page: query.page,
      limit: query.limit,
      items,
      hasMore: items.length === query.limit,
    };
  }
}
