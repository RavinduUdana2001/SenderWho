import "reflect-metadata";
import { ValidationPipe } from "@nestjs/common";
import { UnsubscribeService } from "./unsubscribe.service";
import { ListUnsubscribeCandidatesDto } from "./dto/list-unsubscribe-candidates.dto";

describe("subscription candidate pagination and search", () => {
  function setup() {
    const rows = Array.from({ length: 40 }, (_, i) => ({
      id: `sender-${i}`,
      userId: "owner",
      name: `Sender ${i}`,
      email: `sender${i}@example.com`,
      riskLevel: "LOW",
      messages: [],
      unsubscribeJobs: [],
    }));
    const matching = (where: any) =>
      rows.filter(
        (row) =>
          row.userId === where.userId &&
          (!where.emailAccountId || where.emailAccountId === "owned") &&
          (!where.OR ||
            row.name.includes(where.OR[0].name.contains) ||
            row.email.includes(where.OR[1].email.contains)),
      );
    const findMany = jest.fn(async ({ where, skip, take }) =>
      matching(where).slice(skip, skip + take),
    );
    const count = jest.fn(async ({ where }) => matching(where).length);
    return {
      service: new UnsubscribeService(
        { sender: { findMany, count } } as never,
        {} as never,
      ),
      findMany,
      count,
    };
  }
  it("returns all pages with accurate totals instead of silently stopping at 25", async () => {
    const { service, findMany, count } = setup();
    const one = await service.getCandidates(
      "owner",
      new ListUnsubscribeCandidatesDto(),
    );
    const two = await service.getCandidates(
      "owner",
      Object.assign(new ListUnsubscribeCandidatesDto(), { page: 2 }),
    );
    expect(one).toMatchObject({ total: 40, page: 1, hasMore: true });
    expect(two).toMatchObject({ total: 40, page: 2, hasMore: false });
    expect(new Set([...one.items, ...two.items].map((s) => s.id)).size).toBe(
      40,
    );
    expect(count.mock.calls[1][0].where).toEqual(
      findMany.mock.calls[1][0].where,
    );
    expect(findMany.mock.calls[1][0]).toMatchObject({ skip: 25, take: 25 });
  });
  it("finds a sender beyond the first page through server-side search in the selected mailbox", async () => {
    const { service, findMany } = setup();
    const query = Object.assign(new ListUnsubscribeCandidatesDto(), {
      query: "Sender 39",
      emailAccountId: "owned",
    });
    const result = await service.getCandidates("owner", query);
    expect(result.items.map((s) => s.id)).toEqual(["sender-39"]);
    expect(result).toMatchObject({ total: 1, hasMore: false, page: 1 });
    expect(findMany.mock.calls[0][0].where).toMatchObject({
      userId: "owner",
      emailAccountId: "owned",
      emailAccount: { userId: "owner", syncStatus: { not: "DISCONNECTED" } },
      isTrusted: false,
      isBlocked: false,
    });
    query.emailAccountId = "foreign";
    expect((await service.getCandidates("owner", query)).items).toEqual([]);
  });
  it.each(["ACTIVE", "RETRY"] as const)(
    "applies the %s job filter on the server",
    async (filter) => {
      const { service, findMany } = setup();
      await service.getCandidates(
        "owner",
        Object.assign(new ListUnsubscribeCandidatesDto(), { filter }),
      );
      expect(findMany.mock.calls[0][0].where.AND).toContainEqual({
        unsubscribeJobs: {
          some: {
            status: {
              in:
                filter === "ACTIVE"
                  ? ["QUEUED", "RUNNING"]
                  : ["FAILED", "CANCELED"],
            },
          },
        },
      });
    },
  );
  it("rejects invalid pagination, arbitrary job filters and array search values", async () => {
    const pipe = new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
    });
    for (const input of [
      { page: 0 },
      { limit: 101 },
      { filter: "anything" },
      { query: ["one", "two"] },
      { emailAccountId: { id: "owned" } },
    ]) {
      await expect(
        pipe.transform(input, {
          type: "query",
          metatype: ListUnsubscribeCandidatesDto,
        }),
      ).rejects.toThrow();
    }
  });
});
