import "reflect-metadata";
import { SenderCategory } from "@prisma/client";
import { plainToInstance } from "class-transformer";
import { validateSync } from "class-validator";
import { ListSendersDto } from "./list-senders.dto";

describe("sender category query validation", () => {
  it.each(Object.values(SenderCategory))(
    "accepts %s with pagination and search",
    (category) => {
      const dto = plainToInstance(ListSendersDto, {
        category,
        query: "bank",
        page: "2",
        limit: "25",
      });
      expect(
        validateSync(dto, { whitelist: true, forbidNonWhitelisted: true }),
      ).toEqual([]);
      expect(dto.skip).toBe(25);
    },
  );
  it.each([
    "FINANCE OR 1=1",
    "all",
    ["FINANCE", "PEOPLE"],
    { category: "FINANCE" },
  ])("rejects invalid category %j", (category) => {
    const dto = plainToInstance(ListSendersDto, { category });
    expect(
      validateSync(dto).some((error) => error.property === "category"),
    ).toBe(true);
  });
});
