import { Injectable } from "@nestjs/common";
import { SenderCategory } from "@prisma/client";
import { mockCategories } from "../common/mock/senderwho.mock";
import { PrismaService } from "../database/prisma.service";

type CategoryPresentation = {
  title: string;
  iconKey: string;
  colorKey: string;
};

const CATEGORY_PRESENTATION: Record<SenderCategory, CategoryPresentation> = {
  IMPORTANT: { title: "Important", iconKey: "star", colorKey: "warning" },
  PEOPLE: { title: "People", iconKey: "person", colorKey: "primary" },
  ORDERS: {
    title: "Orders & Purchases",
    iconKey: "shopping_bag",
    colorKey: "orange",
  },
  FINANCE: {
    title: "Finance",
    iconKey: "account_balance",
    colorKey: "success",
  },
  NEWSLETTERS: {
    title: "Newsletters",
    iconKey: "newspaper",
    colorKey: "indigo",
  },
  PROMOTIONS: {
    title: "Promotions",
    iconKey: "sell",
    colorKey: "danger",
  },
  TRAVEL: { title: "Travel", iconKey: "flight", colorKey: "primary" },
  SOCIAL: { title: "Social", iconKey: "person", colorKey: "indigo" },
  SPAM: { title: "Spam / Junk", iconKey: "report", colorKey: "danger" },
  UNKNOWN: { title: "Unknown", iconKey: "report", colorKey: "warning" },
};

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string) {
    if (this.prisma.mockDataEnabled) {
      return { items: mockCategories };
    }

    const grouped = await this.prisma.message.groupBy({
      by: ["category"],
      where: { userId, isTrashed: false },
      _count: {
        _all: true,
      },
    });

    const countByCategory = new Map<string, number>(
      grouped.map((item) => [item.category, item._count._all]),
    );

    const items = Object.values(SenderCategory).map((category) => ({
      id: category.toLowerCase(),
      ...CATEGORY_PRESENTATION[category],
      count: countByCategory.get(category) ?? 0,
    }));

    return { items };
  }
}
