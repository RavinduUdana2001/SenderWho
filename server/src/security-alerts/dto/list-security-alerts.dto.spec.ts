import "reflect-metadata";
import { plainToInstance } from "class-transformer";
import { validate } from "class-validator";
import { ListSecurityAlertsDto } from "./list-security-alerts.dto";

describe("ListSecurityAlertsDto", () => {
  it("transforms and accepts bounded pagination values", async () => {
    const query = plainToInstance(ListSecurityAlertsDto, {
      page: "2",
      limit: "100",
    });

    await expect(validate(query)).resolves.toHaveLength(0);
    expect(query).toMatchObject({ page: 2, limit: 100 });
    expect(query.skip).toBe(100);
  });

  it.each([
    { page: "0", limit: "25" },
    { page: "1", limit: "0" },
    { page: "1", limit: "101" },
    { page: "not-a-number", limit: "25" },
  ])("rejects invalid pagination: %o", async (input) => {
    const query = plainToInstance(ListSecurityAlertsDto, input);

    expect(await validate(query)).not.toHaveLength(0);
  });
});
