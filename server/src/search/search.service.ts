import { Injectable } from "@nestjs/common";
import { Prisma, SenderCategory } from "@prisma/client";
import { PrismaService } from "../database/prisma.service";
import { SearchDto } from "./dto/search.dto";

const CATEGORY_LABELS: Record<string, SenderCategory> = {
  Important: SenderCategory.IMPORTANT,
  People: SenderCategory.PEOPLE,
  Orders: SenderCategory.ORDERS,
  Finance: SenderCategory.FINANCE,
  Newsletters: SenderCategory.NEWSLETTERS,
  Promotions: SenderCategory.PROMOTIONS,
  Travel: SenderCategory.TRAVEL,
  Social: SenderCategory.SOCIAL,
  Spam: SenderCategory.SPAM,
};

@Injectable()
export class SearchService {
  constructor(private readonly prisma: PrismaService) {}

  getFilters() {
    return {
      categories: Object.keys(CATEGORY_LABELS),
      trustScores: ["All", "High (75+)", "Medium (50-74)", "Low (<50)"],
      dateRanges: ["Any time", "Today", "This Week", "This Month"],
    };
  }

  async search(userId: string, body: SearchDto) {
    const query = body.query?.trim() ?? "";
    const selected = body.selected ?? [];
    const categories = selected
      .map((item) => CATEGORY_LABELS[item])
      .filter((item): item is SenderCategory => Boolean(item));
    const unreadOnly = body.unreadOnly === true;
    const hasAttachments = body.hasAttachments === true;
    const trustScore = this.trustScoreFilter(selected);
    const receivedAfter = this.receivedAfter(selected);
    const page = body.page;
    const limit = body.limit;
    const skip = (page - 1) * limit;
    const senderFilters: Prisma.SenderWhereInput = {
      ...(categories.length > 0 ? { category: { in: categories } } : {}),
      ...(trustScore ? { trustScore } : {}),
    };

    const senderWhere: Prisma.SenderWhereInput = {
      userId,
      ...(query
        ? {
            OR: [
              { name: { contains: query } },
              { email: { contains: query } },
              { domain: { contains: query } },
            ],
          }
        : {}),
      ...senderFilters,
      ...(receivedAfter ? { lastSeenAt: { gte: receivedAfter } } : {}),
    };
    const messageWhere: Prisma.MessageWhereInput = {
      userId,
      isTrashed: false,
      ...(unreadOnly ? { isRead: false } : {}),
      ...(hasAttachments ? { hasAttachments: true } : {}),
      ...(receivedAfter ? { receivedAt: { gte: receivedAfter } } : {}),
      ...(categories.length > 0 ? { category: { in: categories } } : {}),
      ...(query
        ? {
            OR: [
              { subject: { contains: query } },
              { sender: { name: { contains: query } } },
              { sender: { email: { contains: query } } },
            ],
          }
        : {}),
      ...(trustScore ? { sender: { trustScore } } : {}),
    };

    const [senders, messages, senderCount, messageCount] = await Promise.all([
      this.prisma.sender.findMany({
        where: senderWhere,
        orderBy: { lastSeenAt: "desc" },
        skip,
        take: limit,
      }),
      this.prisma.message.findMany({
        where: messageWhere,
        include: { sender: true },
        orderBy: { receivedAt: "desc" },
        skip,
        take: limit,
      }),
      this.prisma.sender.count({ where: senderWhere }),
      this.prisma.message.count({ where: messageWhere }),
    ]);

    return {
      query,
      filters: { selected, unreadOnly, hasAttachments },
      senders: senders.map((sender) => ({
        id: sender.id,
        name: sender.name ?? sender.email,
        email: sender.email,
        category: sender.category,
        score: sender.trustScore,
      })),
      emails: messages.map((message) => ({
        id: message.id,
        sender: message.sender?.name ?? message.sender?.email ?? "Unknown",
        email: message.sender?.email ?? "",
        subject: message.subject ?? "(No subject)",
        date: message.receivedAt.toISOString(),
        isRead: message.isRead,
        hasAttachments: message.hasAttachments,
      })),
      total: senderCount + messageCount,
      returned: senders.length + messages.length,
      page,
      limit,
      hasMore:
        skip + senders.length < senderCount ||
        skip + messages.length < messageCount,
    };
  }

  private trustScoreFilter(
    selected: string[],
  ): Prisma.IntFilter<"Sender"> | undefined {
    if (selected.includes("High (75+)")) return { gte: 75 };
    if (selected.includes("Medium (50-74)")) return { gte: 50, lte: 74 };
    if (selected.includes("Low (<50)")) return { lt: 50 };
    return undefined;
  }

  private receivedAfter(selected: string[]) {
    const now = new Date();
    if (selected.includes("Today")) {
      return new Date(now.getFullYear(), now.getMonth(), now.getDate());
    }
    if (selected.includes("This Week")) {
      const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      start.setDate(start.getDate() - ((start.getDay() + 6) % 7));
      return start;
    }
    if (selected.includes("This Month")) {
      return new Date(now.getFullYear(), now.getMonth(), 1);
    }
    return undefined;
  }
}
