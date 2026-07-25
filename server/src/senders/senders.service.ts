import { Injectable, Logger, NotFoundException } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import {
  mockPromotionEmails,
  mockSenders,
} from "../common/mock/senderwho.mock";
import { PrismaService } from "../database/prisma.service";
import {
  ListSendersDto,
  SenderControl,
  SenderKind,
} from "./dto/list-senders.dto";

@Injectable()
export class SendersService {
  private readonly logger = new Logger(SendersService.name);

  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string, pagination: ListSendersDto) {
    if (this.prisma.mockDataEnabled) {
      return {
        items: mockSenders,
        total: mockSenders.length,
        page: pagination.page,
        limit: pagination.limit,
      };
    }

    const text = pagination.query?.trim();
    const kindWhere: Prisma.SenderWhereInput = (() => {
      switch (pagination.kind) {
        case SenderKind.PEOPLE:
          return { category: "PEOPLE" };
        case SenderKind.NEWSLETTERS:
          return { category: "NEWSLETTERS" };
        case SenderKind.COMPANIES:
          return { category: { notIn: ["PEOPLE", "NEWSLETTERS"] } };
        case SenderKind.ALL:
          return {};
      }
    })();
    const where: Prisma.SenderWhereInput = {
      userId,
      ...kindWhere,
      ...(pagination.control === SenderControl.BLOCKED
        ? { isBlocked: true }
        : pagination.control === SenderControl.TRUSTED
          ? { isTrusted: true }
          : {}),
      ...(text
        ? {
            OR: [
              { name: { contains: text } },
              { email: { contains: text } },
              { domain: { contains: text } },
            ],
          }
        : {}),
    };
    const [items, total] = await Promise.all([
      this.prisma.sender.findMany({
        where,
        skip: pagination.skip,
        take: pagination.limit,
        orderBy: [{ riskLevel: "desc" }, { lastSeenAt: "desc" }],
      }),
      this.prisma.sender.count({ where }),
    ]);

    return {
      items: items.map((sender) => ({
        id: sender.id,
        name: sender.name ?? sender.email,
        email: sender.email,
        category: sender.category
          .toLowerCase()
          .replaceAll("_", " ")
          .replace(/\b\w/g, (letter) => letter.toUpperCase()),
        score: sender.trustScore,
        initial: (sender.name ?? sender.email).substring(0, 1).toUpperCase(),
        colorKey: sender.riskLevel === "HIGH" ? "danger" : "primary",
        totalMessages: sender.totalMessages,
        unreadMessages: sender.unreadMessages,
        riskLevel: sender.riskLevel,
        identityStatus: sender.identityStatus,
        identityRiskLevel: sender.identityRiskLevel,
        identityRiskScore: sender.identityRiskScore,
        isBlocked: sender.isBlocked,
        isTrusted: sender.isTrusted,
      })),
      total,
      page: pagination.page,
      limit: pagination.limit,
    };
  }

  async getTopSenders(userId: string) {
    if (this.prisma.mockDataEnabled) {
      return {
        items: mockSenders
          .slice()
          .sort((first, second) => second.totalMessages - first.totalMessages)
          .map((sender, index) => ({
            rank: index + 1,
            id: sender.id,
            name: sender.name,
            email: sender.email,
            count: sender.totalMessages,
          })),
      };
    }

    const senders = await this.prisma.sender.findMany({
      where: { userId },
      orderBy: { totalMessages: "desc" },
      take: 10,
    });

    return {
      items: senders.map((sender, index) => ({
        rank: index + 1,
        id: sender.id,
        name: sender.name ?? sender.email,
        email: sender.email,
        count: sender.totalMessages,
      })),
    };
  }

  async getById(userId: string, id: string) {
    const mockSender = this.prisma.mockDataEnabled
      ? mockSenders.find((sender) => sender.id === id)
      : undefined;
    if (mockSender) {
      return {
        ...mockSender,
        messages: mockPromotionEmails.slice(0, 4),
        alerts: [],
      };
    }

    const sender = await this.prisma.sender.findFirst({
      where: { id, userId },
      include: {
        messages: {
          take: 25,
          orderBy: { receivedAt: "desc" },
        },
        alerts: {
          take: 10,
          orderBy: { detectedAt: "desc" },
        },
      },
    });
    if (!sender) throw new NotFoundException("Sender not found");
    return {
      id: sender.id,
      name: sender.name ?? sender.email,
      email: sender.email,
      category: sender.category
        .toLowerCase()
        .replaceAll("_", " ")
        .replace(/\b\w/g, (letter) => letter.toUpperCase()),
      score: sender.trustScore,
      initial: (sender.name ?? sender.email).substring(0, 1).toUpperCase(),
      colorKey: sender.riskLevel === "HIGH" ? "danger" : "primary",
      firstSeenAt: sender.firstSeenAt?.toISOString(),
      type: sender.category,
      totalMessages: sender.totalMessages,
      unreadMessages: sender.unreadMessages,
      riskLevel: sender.riskLevel,
      identityStatus: sender.identityStatus,
      identityRiskLevel: sender.identityRiskLevel,
      identityRiskScore: sender.identityRiskScore,
      isBlocked: sender.isBlocked,
      isTrusted: sender.isTrusted,
      messages: sender.messages.map((message) => ({
        id: message.id,
        sender: sender.name ?? sender.email,
        email: sender.email,
        subject: message.subject ?? "(No subject)",
        date: message.receivedAt.toISOString(),
        isRead: message.isRead,
        isArchived: message.isArchived,
        isTrashed: message.isTrashed,
        identityStatus: message.identityStatus,
        identityRiskLevel: message.identityRiskLevel,
        identityRiskScore: message.identityRiskScore,
        identityEvidence: message.identityEvidence,
        claimedBrand: message.claimedBrand,
        authenticatedDomain: message.authenticatedDomain,
        replyToEmail: message.replyToEmail,
      })),
      alerts: sender.alerts,
    };
  }

  async setBlocked(userId: string, id: string, blocked: boolean) {
    if (
      this.prisma.mockDataEnabled &&
      mockSenders.some((sender) => sender.id === id)
    ) {
      return {
        id,
        isBlocked: blocked,
        isTrusted: blocked ? false : undefined,
      };
    }

    const sender = await this.prisma.sender.findFirst({
      where: { id, userId },
      select: { id: true },
    });
    if (!sender) throw new NotFoundException("Sender not found");
    const updated = await this.prisma.sender.update({
      where: { id: sender.id },
      data: { isBlocked: blocked, isTrusted: blocked ? false : undefined },
    });
    await this.safeAudit(
      userId,
      sender.id,
      blocked ? "sender.blocked" : "sender.unblocked",
      blocked,
    );
    return updated;
  }

  async setTrusted(userId: string, id: string, trusted: boolean) {
    if (
      this.prisma.mockDataEnabled &&
      mockSenders.some((sender) => sender.id === id)
    ) {
      return {
        id,
        isTrusted: trusted,
        isBlocked: trusted ? false : undefined,
      };
    }

    const sender = await this.prisma.sender.findFirst({
      where: { id, userId },
      select: { id: true },
    });
    if (!sender) throw new NotFoundException("Sender not found");
    const updated = await this.prisma.sender.update({
      where: { id: sender.id },
      data: { isTrusted: trusted, isBlocked: trusted ? false : undefined },
    });
    await this.safeAudit(
      userId,
      sender.id,
      trusted ? "sender.trusted" : "sender.untrusted",
      true,
    );
    return updated;
  }

  private async safeAudit(
    userId: string,
    senderId: string,
    action: string,
    securityEvent: boolean,
  ) {
    try {
      await this.prisma.auditLog.create({
        data: {
          userId,
          action,
          targetType: "Sender",
          targetId: senderId,
          metadata: { securityEvent },
        },
      });
    } catch (error) {
      this.logger.error(
        JSON.stringify({
          event: "sender.audit.failed",
          targetId: senderId,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
    }
  }
}
