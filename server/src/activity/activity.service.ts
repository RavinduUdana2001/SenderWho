import { Injectable } from "@nestjs/common";
import { PrismaService } from "../database/prisma.service";

@Injectable()
export class ActivityService {
  constructor(private readonly prisma: PrismaService) {}

  async getInsights(userId: string) {
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    const startOfWeek = new Date(startOfToday);
    startOfWeek.setDate(startOfToday.getDate() - 6);

    const [received, cleaned, recentMessages] = await Promise.all([
      this.prisma.message.count({
        where: { userId, receivedAt: { gte: startOfWeek } },
      }),
      this.prisma.cleanupJobItem.aggregate({
        where: {
          status: "COMPLETED",
          processedAt: { gte: startOfWeek },
          cleanupJob: { userId },
        },
        _count: { _all: true },
        _sum: { sizeBytes: true },
      }),
      this.prisma.message.findMany({
        where: { userId, receivedAt: { gte: startOfWeek } },
        select: { receivedAt: true },
      }),
    ]);

    const counts = ListFactory.sevenZeros();
    for (const message of recentMessages) {
      const dayOffset = Math.floor(
        (message.receivedAt.getTime() - startOfWeek.getTime()) /
          (24 * 60 * 60 * 1_000),
      );
      if (dayOffset >= 0 && dayOffset < counts.length) counts[dayOffset] += 1;
    }
    const maxCount = Math.max(1, ...counts);
    const formatter = new Intl.DateTimeFormat("en", { weekday: "short" });

    return {
      period: "Last 7 Days",
      stats: [
        {
          key: "emailsReceived",
          value: String(received),
          label: "Emails Received",
          colorKey: "text",
        },
        {
          key: "emailsCleaned",
          value: String(cleaned._count._all),
          label: "Emails Cleaned",
          colorKey: "success",
        },
        {
          key: "spaceSaved",
          value: this.formatBytes(cleaned._sum.sizeBytes ?? 0),
          label: "Cleanup Volume",
          colorKey: "indigo",
        },
      ],
      weeklyActivity: counts.map((count, index) => {
        const day = new Date(startOfWeek);
        day.setDate(startOfWeek.getDate() + index);
        return { day: formatter.format(day), value: count / maxCount };
      }),
    };
  }

  private formatBytes(bytes: number) {
    if (bytes < 1_000_000) return `${Math.round(bytes / 1_000)} KB`;
    if (bytes < 1_000_000_000) return `${Math.round(bytes / 1_000_000)} MB`;
    return `${(bytes / 1_000_000_000).toFixed(1)} GB`;
  }
}

class ListFactory {
  static sevenZeros() {
    return Array.from({ length: 7 }, () => 0);
  }
}
