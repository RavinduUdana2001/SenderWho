import { Injectable, Logger, NotFoundException } from "@nestjs/common";
import { mockAlerts } from "../common/mock/senderwho.mock";
import { PrismaService } from "../database/prisma.service";
import { ListSecurityAlertsDto } from "./dto/list-security-alerts.dto";

@Injectable()
export class SecurityAlertsService {
  private readonly logger = new Logger(SecurityAlertsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string, query = new ListSecurityAlertsDto()) {
    if (this.prisma.mockDataEnabled) {
      const items = mockAlerts.slice(query.skip, query.skip + query.limit);
      return {
        items: items.map((alert) => ({
          ...alert,
          senderId: "",
          messageId: "",
        })),
        total: mockAlerts.length,
        page: query.page,
        limit: query.limit,
        hasMore: query.skip + items.length < mockAlerts.length,
      };
    }

    const where = { userId, status: "OPEN" as const };
    const [total, alerts] = await Promise.all([
      this.prisma.securityAlert.count({ where }),
      this.prisma.securityAlert.findMany({
        where,
        orderBy: [{ riskLevel: "desc" }, { detectedAt: "desc" }],
        skip: query.skip,
        take: query.limit,
        include: { sender: true, message: true },
      }),
    ]);

    return {
      items: alerts.map((alert) => this.toAlertItem(alert)),
      total,
      page: query.page,
      limit: query.limit,
      hasMore: query.skip + alerts.length < total,
    };
  }

  async getById(userId: string, id: string) {
    const mockAlert = this.prisma.mockDataEnabled
      ? mockAlerts.find((alert) => alert.id === id)
      : undefined;
    if (mockAlert) return { ...mockAlert, senderId: "", messageId: "" };

    const alert = await this.prisma.securityAlert.findFirst({
      where: { id, userId },
      include: { sender: true, message: true },
    });
    if (!alert) throw new NotFoundException("Security alert not found");
    return this.toAlertItem(alert);
  }

  async resolve(userId: string, id: string) {
    if (
      this.prisma.mockDataEnabled &&
      mockAlerts.some((alert) => alert.id === id)
    ) {
      return {
        id,
        status: "RESOLVED",
        resolvedAt: new Date().toISOString(),
      };
    }

    const alert = await this.prisma.securityAlert.findFirst({
      where: { id, userId },
      select: { id: true },
    });
    if (!alert) throw new NotFoundException("Security alert not found");
    const resolved = await this.prisma.securityAlert.update({
      where: { id: alert.id },
      data: { status: "RESOLVED", resolvedAt: new Date() },
    });
    await this.safeAudit(userId, alert.id, "security_alert.resolved");
    return resolved;
  }

  async dismiss(userId: string, id: string) {
    if (
      this.prisma.mockDataEnabled &&
      mockAlerts.some((alert) => alert.id === id)
    ) {
      return {
        id,
        status: "DISMISSED",
        resolvedAt: new Date().toISOString(),
      };
    }

    const alert = await this.prisma.securityAlert.findFirst({
      where: { id, userId },
      select: { id: true },
    });
    if (!alert) throw new NotFoundException("Security alert not found");
    const dismissed = await this.prisma.securityAlert.update({
      where: { id: alert.id },
      data: { status: "DISMISSED", resolvedAt: new Date() },
    });
    await this.safeAudit(userId, alert.id, "security_alert.dismissed");
    return dismissed;
  }

  private async safeAudit(userId: string, alertId: string, action: string) {
    try {
      await this.prisma.auditLog.create({
        data: {
          userId,
          action,
          targetType: "SecurityAlert",
          targetId: alertId,
          metadata: { securityEvent: true },
        },
      });
    } catch (error) {
      this.logger.error(
        JSON.stringify({
          event: "security_alert.audit.failed",
          targetId: alertId,
          errorType: error instanceof Error ? error.name : "UnknownError",
        }),
      );
    }
  }

  private toAlertItem(alert: {
    id: string;
    senderId: string | null;
    messageId: string | null;
    title: string;
    reason: string;
    detectedAt: Date;
    riskLevel: string;
    status: string;
    sender?: { email: string } | null;
    message?: {
      identityRiskScore: number;
      identityRiskLevel: string;
      identityStatus: string;
      identityEvidence: unknown;
      claimedBrand: string | null;
      authenticatedDomain: string | null;
      replyToEmail: string | null;
    } | null;
  }) {
    return {
      id: alert.id,
      senderId: alert.senderId ?? "",
      messageId: alert.messageId ?? "",
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
    };
  }
}
