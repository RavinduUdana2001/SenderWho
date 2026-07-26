import { Injectable } from "@nestjs/common";
import { CleanupCategory } from "@prisma/client";
import { buildCleanupMessageWhere } from "../cleanup/cleanup.service";
import {
  mockAlerts,
  mockDashboard,
  mockSenders,
} from "../common/mock/senderwho.mock";
import { PrismaService } from "../database/prisma.service";
import { InboxHealthService } from "../inbox-health/inbox-health.service";
import { getGoogleAccountRecoveryAction } from "../providers/google-account-recovery";

@Injectable()
export class DashboardService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly inboxHealthService: InboxHealthService,
  ) {}

  async getDashboardSummary(userId: string) {
    if (this.prisma.mockDataEnabled) {
      return {
        ...mockDashboard,
        topSenders: mockSenders.slice(0, 3),
        recentAlerts: mockAlerts,
      };
    }

    const { emailAccountId: _accountScope, ...cleanupOpportunityWhere } =
      buildCleanupMessageWhere(
        "dashboard-user-scope",
        Object.values(CleanupCategory),
      );

    const [
      totalSenders,
      totalMessages,
      unreadEmails,
      newsletters,
      promotions,
      spam,
      topSenders,
      recentAlerts,
      openAlertCount,
      latestAccount,
      cleanupOpportunity,
      unsubscribeSenders,
      inboxHealth,
    ] = await Promise.all([
      this.prisma.sender.count({ where: { userId } }),
      this.prisma.message.count({ where: { userId, isTrashed: false } }),
      this.prisma.message.count({
        where: { userId, isRead: false, isTrashed: false },
      }),
      this.prisma.message.count({
        where: {
          userId,
          isTrashed: false,
          category: "NEWSLETTERS",
        },
      }),
      this.prisma.message.count({
        where: {
          userId,
          isTrashed: false,
          category: "PROMOTIONS",
        },
      }),
      this.prisma.message.count({
        where: { userId, isTrashed: false, category: "SPAM" },
      }),
      this.prisma.sender.findMany({
        where: { userId },
        orderBy: { totalMessages: "desc" },
        take: 3,
      }),
      this.prisma.securityAlert.findMany({
        where: { userId, status: "OPEN" },
        take: 5,
        orderBy: { detectedAt: "desc" },
        include: {
          sender: { select: { email: true } },
          message: true,
        },
      }),
      this.prisma.securityAlert.count({
        where: { userId, status: "OPEN" },
      }),
      this.prisma.emailAccount.findFirst({
        where: { userId },
        orderBy: { createdAt: "desc" },
        select: {
          id: true,
          emailAddress: true,
          syncStatus: true,
          lastSyncedAt: true,
          lastSyncError: true,
        },
      }),
      this.prisma.message.aggregate({
        where: {
          userId,
          ...cleanupOpportunityWhere,
        },
        _count: { _all: true },
        _sum: { sizeBytes: true },
      }),
      this.prisma.sender.count({
        where: {
          userId,
          isTrusted: false,
          isBlocked: false,
          messages: {
            some: {
              isTrashed: false,
              listUnsubscribePost: true,
              listUnsubscribeUrl: { not: null },
            },
          },
          unsubscribeJobs: { none: { status: "COMPLETED" } },
        },
      }),
      this.inboxHealthService.getHealth(userId),
    ]);

    return {
      inboxHealth: {
        score: inboxHealth.score,
        status: inboxHealth.status,
      },
      metrics: {
        totalMessages,
        totalSenders,
        unreadEmails,
        newsletters,
        promotions,
        spam,
      },
      opportunities: {
        cleanupMessages: cleanupOpportunity._count._all,
        estimatedSpaceBytes: cleanupOpportunity._sum.sizeBytes ?? 0,
        unsubscribeSenders,
      },
      topSenders: topSenders.map((sender, index) => ({
        rank: index + 1,
        id: sender.id,
        name: sender.name ?? sender.email,
        email: sender.email,
        count: sender.totalMessages,
      })),
      recentAlerts: recentAlerts.map((alert) => ({
        id: alert.id,
        senderId: alert.senderId,
        title: alert.title,
        email: alert.sender?.email ?? "",
        reason: alert.reason,
        time: alert.detectedAt.toISOString(),
        risk: `${alert.riskLevel[0]}${alert.riskLevel.slice(1).toLowerCase()} Risk`,
        colorKey: alert.riskLevel === "HIGH" ? "danger" : "warning",
        status: alert.status,
        identityRiskScore: alert.message?.identityRiskScore ?? 0,
        identityRiskLevel: alert.message?.identityRiskLevel ?? "LOW",
        identityStatus: alert.message?.identityStatus ?? "UNVERIFIED",
        identityEvidence: alert.message?.identityEvidence ?? [],
        claimedBrand: alert.message?.claimedBrand,
        authenticatedDomain: alert.message?.authenticatedDomain,
        replyToEmail: alert.message?.replyToEmail,
      })),
      openAlertCount,
      sync: latestAccount
        ? {
            ...latestAccount,
            recoveryAction: getGoogleAccountRecoveryAction(
              latestAccount.syncStatus,
              latestAccount.lastSyncError,
            ),
          }
        : null,
    };
  }
}
