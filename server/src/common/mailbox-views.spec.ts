import { SendersService } from "../senders/senders.service";
import { EmailMessagesService } from "../email-messages/email-messages.service";
import { SearchService } from "../search/search.service";
import { UnsubscribeService } from "../unsubscribe/unsubscribe.service";
import { CleanupService } from "../cleanup/cleanup.service";
import { ListSendersDto } from "../senders/dto/list-senders.dto";
import { ListMessagesDto } from "../email-messages/dto/list-messages.dto";
import { SearchDto } from "../search/dto/search.dto";

// Exercise the predicates against distinct mailboxes, including foreign and
// disconnected records. This catches an accidental return to user-wide lists.
describe("Selected mailbox views", () => {
  function setup() {
    const accounts = [
      { id: "personal", userId: "owner", isPrimary: true, syncStatus: "READY" },
      { id: "work", userId: "owner", isPrimary: false, syncStatus: "READY" },
      {
        id: "foreign",
        userId: "another-user",
        isPrimary: true,
        syncStatus: "READY",
      },
      {
        id: "disconnected",
        userId: "owner",
        isPrimary: false,
        syncStatus: "DISCONNECTED",
      },
    ];
    const rows = accounts.map((account) => ({
      id: account.id,
      userId: account.userId,
      emailAccountId: account.id,
      emailAccount: { ...account, emailAddress: `${account.id}@example.com` },
      name: account.id,
      email: `${account.id}@example.com`,
      category: "NEWSLETTERS",
      trustScore: 70,
      riskLevel: "LOW",
      subject: account.id,
      isRead: false,
      receivedAt: new Date("2026-11-04T08:00:00Z"),
      totalMessages: 1,
      sender: { name: account.id, email: `${account.id}@example.com` },
      messages: [{ receivedAt: new Date("2026-11-04T08:00:00Z") }],
      messageCount: 1,
      estimatedSpaceBytes: 10,
    }));
    const matching = ({ where }: any) =>
      rows.filter((row) => {
        const account = accounts.find((a) => a.id === row.emailAccountId)!;
        const scope = where.emailAccount;
        return (
          row.userId === where.userId &&
          (!where.emailAccountId ||
            row.emailAccountId === where.emailAccountId) &&
          (!scope ||
            (account.userId === scope.userId &&
              (scope.isPrimary === undefined ||
                account.isPrimary === scope.isPrimary) &&
              account.syncStatus !== scope.syncStatus.not))
        );
      });
    const model = () => ({
      findMany: jest.fn(async (args) => matching(args)),
      count: jest.fn(async (args) => matching(args).length),
    });
    const prisma = {
      sender: model(),
      message: model(),
      cleanupSuggestion: model(),
    };
    return {
      prisma,
      select(id: string) {
        for (const account of accounts) account.isPrimary = account.id === id;
      },
    };
  }

  for (const selected of ["personal", "work"]) {
    it(`lists only ${selected} senders and messages with matching totals`, async () => {
      const { prisma, select } = setup();
      select(selected);
      const senders = new SendersService(prisma as never);
      const emails = new EmailMessagesService(
        prisma as never,
        {} as never,
        {} as never,
        {} as never,
      );
      const senderPage = await senders.list("owner", new ListSendersDto());
      const emailPage = await emails.list("owner", new ListMessagesDto());
      expect(senderPage.items.map((row) => row.id)).toEqual([selected]);
      expect(emailPage.items.map((row) => row.id)).toEqual([selected]);
      expect(senderPage.total).toBe(1);
      expect(emailPage.total).toBe(1);
    });
  }

  it("switches back without leaking metadata from the previous mailbox", async () => {
    const { prisma, select } = setup();
    const service = new SendersService(prisma as never);
    for (const id of ["personal", "work", "personal"]) {
      select(id);
      expect(
        (await service.list("owner", new ListSendersDto())).items.map(
          (s) => s.id,
        ),
      ).toEqual([id]);
    }
  });

  it("honors an explicitly selected owned mailbox even while the default selection is stale", async () => {
    const { prisma } = setup();
    const senders = new SendersService(prisma as never);
    const emails = new EmailMessagesService(
      prisma as never,
      {} as never,
      {} as never,
      {} as never,
    );
    const senderQuery = Object.assign(new ListSendersDto(), {
      emailAccountId: "work",
    });
    const emailQuery = Object.assign(new ListMessagesDto(), {
      emailAccountId: "work",
    });
    expect(
      (await senders.list("owner", senderQuery)).items.map((s) => s.id),
    ).toEqual(["work"]);
    expect(
      (await emails.list("owner", emailQuery)).items.map((s) => s.id),
    ).toEqual(["work"]);
    for (const foreign of ["foreign", "disconnected"]) {
      senderQuery.emailAccountId = foreign;
      emailQuery.emailAccountId = foreign;
      expect((await senders.list("owner", senderQuery)).total).toBe(0);
      expect((await emails.list("owner", emailQuery)).total).toBe(0);
    }
  });

  it("scopes advanced search, unsubscribe candidates and cleanup suggestions to the same mailbox", async () => {
    const { prisma, select } = setup();
    select("work");
    const search = await new SearchService(prisma as never).search(
      "owner",
      new SearchDto(),
    );
    expect(search.senders.map((s) => s.id)).toEqual(["work"]);
    expect(search.emails.map((s) => s.id)).toEqual(["work"]);
    const candidates = await new UnsubscribeService(
      prisma as never,
      {} as never,
    ).getCandidates("owner");
    const cleanup = await new CleanupService(
      prisma as never,
      {} as never,
    ).getSuggestions("owner");
    expect(candidates.items.map((s) => s.id)).toEqual(["work"]);
    expect(cleanup.items.map((s) => s.id)).toEqual(["work"]);
  });

  it("does not fall back to disconnected or foreign metadata when no mailbox is selected", async () => {
    const { prisma, select } = setup();
    select("disconnected");
    const service = new SendersService(prisma as never);
    expect((await service.list("owner", new ListSendersDto())).total).toBe(0);
  });
});
