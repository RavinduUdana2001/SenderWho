import { Injectable } from "@nestjs/common";
import { PrismaService } from "../database/prisma.service";

@Injectable()
export class InboxHealthService {
  constructor(private readonly prisma: PrismaService) {}

  async getHealth(userId: string) {
    const [totalMessages, spamMessages, clutterMessages, senderTrust] =
      await Promise.all([
        this.prisma.message.count({ where: { userId, isTrashed: false } }),
        this.prisma.message.count({
          where: { userId, isTrashed: false, category: "SPAM" },
        }),
        this.prisma.message.count({
          where: {
            userId,
            isTrashed: false,
            category: { in: ["NEWSLETTERS", "PROMOTIONS"] },
          },
        }),
        this.prisma.sender.aggregate({
          where: { userId },
          _avg: { trustScore: true },
          _count: { _all: true },
        }),
      ]);
    const ratio = (value: number, total: number) =>
      total === 0 ? 0 : value / total;
    const senderTrustScore = Math.round(senderTrust._avg.trustScore ?? 0);
    const spamProtection = Math.round(
      100 - ratio(spamMessages, totalMessages) * 100,
    );
    const inboxClutter = Math.round(
      100 - ratio(clutterMessages, totalMessages) * 100,
    );
    const score =
      totalMessages === 0
        ? 0
        : Math.round(
            senderTrustScore * 0.35 +
              spamProtection * 0.4 +
              inboxClutter * 0.25,
          );

    return {
      score,
      status:
        totalMessages === 0
          ? "Waiting for scan"
          : score >= 80
            ? "Good"
            : score >= 60
              ? "Needs attention"
              : "At risk",
      breakdown: [
        {
          key: "senderTrust",
          label: "Sender Trust",
          score: senderTrustScore,
          available: senderTrust._count._all > 0,
          body:
            senderTrust._count._all === 0
              ? "No sender trust data has been scanned yet."
              : `Average trust across ${senderTrust._count._all} sender${senderTrust._count._all === 1 ? "" : "s"}.`,
        },
        {
          key: "spamProtection",
          label: "Spam Protection",
          score: spamProtection,
          available: totalMessages > 0,
          body:
            totalMessages === 0
              ? "No message data has been scanned yet."
              : spamMessages === 0
                ? `No spam detected across ${totalMessages} scanned message${totalMessages === 1 ? "" : "s"}.`
                : `${spamMessages} of ${totalMessages} scanned messages classified as spam.`,
        },
        {
          key: "inboxClutter",
          label: "Inbox Clutter",
          score: inboxClutter,
          available: totalMessages > 0,
          body:
            totalMessages === 0
              ? "No message data has been scanned yet."
              : clutterMessages === 0
                ? "No promotions or newsletters currently add inbox clutter."
                : `${clutterMessages} of ${totalMessages} messages are promotions or newsletters.`,
        },
      ],
    };
  }
}
