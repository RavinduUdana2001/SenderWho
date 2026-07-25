import { SenderCategory } from "@prisma/client";
import { CategoriesService } from "./categories.service";

describe("CategoriesService", () => {
  it("returns every production sender category with real per-user counts", async () => {
    const prisma = {
      mockDataEnabled: false,
      message: {
        groupBy: jest.fn().mockResolvedValue([
          { category: SenderCategory.IMPORTANT, _count: { _all: 3 } },
          { category: SenderCategory.SOCIAL, _count: { _all: 7 } },
          { category: SenderCategory.UNKNOWN, _count: { _all: 2 } },
        ]),
      },
    };
    const service = new CategoriesService(prisma as never);

    const result = await service.list("user-1");

    expect(prisma.message.groupBy).toHaveBeenCalledWith({
      by: ["category"],
      where: { userId: "user-1", isTrashed: false },
      _count: { _all: true },
    });
    expect(result.items).toHaveLength(Object.values(SenderCategory).length);
    expect(result.items.map((item) => item.id)).toEqual(
      Object.values(SenderCategory).map((category) => category.toLowerCase()),
    );
    expect(result.items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: "important", count: 3 }),
        expect.objectContaining({ id: "social", title: "Social", count: 7 }),
        expect.objectContaining({ id: "unknown", title: "Unknown", count: 2 }),
        expect.objectContaining({ id: "finance", count: 0 }),
      ]),
    );
  });
});
