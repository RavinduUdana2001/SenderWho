import "reflect-metadata";
import { ValidationPipe } from "@nestjs/common";
import { ListSendersDto } from "./dto/list-senders.dto";
import { SendersController } from "./senders.controller";
import { SendersService } from "./senders.service";

describe("Sender category request flow", () => {
  it.each(["PEOPLE", "NEWSLETTERS", "FINANCE", "PROMOTIONS"])(
    "retains %s category, search, and mailbox through query validation into list and count",
    async (category) => {
      const findMany = jest.fn().mockResolvedValue([]);
      const count = jest.fn().mockResolvedValue(0);
      const service = new SendersService({
        sender: { findMany, count },
      } as never);
      const controller = new SendersController(service);
      const pipe = new ValidationPipe({
        transform: true,
        whitelist: true,
        forbidNonWhitelisted: true,
      });
      const kind = ["PEOPLE", "NEWSLETTERS"].includes(category)
        ? category
        : "ALL";
      const query = await pipe.transform(
        {
          page: "1",
          limit: "25",
          kind,
          category,
          query: "updates",
          emailAccountId: "second-account",
        },
        { type: "query", metatype: ListSendersDto },
      );
      await controller.list("owner", query);
      const where = findMany.mock.calls[0][0].where;
      expect(where).toMatchObject({
        userId: "owner",
        emailAccountId: "second-account",
        emailAccount: { userId: "owner", syncStatus: { not: "DISCONNECTED" } },
        AND: expect.arrayContaining([{ category }]),
        OR: expect.arrayContaining([{ name: { contains: "updates" } }]),
      });
      expect(count).toHaveBeenCalledWith({ where });
    },
  );
});
