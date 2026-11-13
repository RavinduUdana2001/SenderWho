import { ConsoleLogger } from "@nestjs/common";
import { ProductionLogger } from "./production-logger";
describe("production framework error logging", () => {
  afterEach(() => jest.restoreAllMocks());
  it("drops raw exception messages, stack and optional parameters", () => {
    const output = jest
      .spyOn(ConsoleLogger.prototype, "error")
      .mockImplementation(() => undefined);
    const logger = new ProductionLogger();
    logger.error(
      new Error("SYNTHETIC_PASSWORD"),
      "SYNTHETIC_ACCESS_TOKEN",
      "/private/internal",
    );
    logger.error("provider rejected SYNTHETIC_REFRESH_TOKEN", "raw stack");
    expect(output.mock.calls).toEqual([
      [JSON.stringify({ event: "application.error" }), "Production"],
      [JSON.stringify({ event: "application.error" }), "Production"],
    ]);
  });
  it("keeps structured diagnostics but discards unreviewed fields", () => {
    const output = jest
      .spyOn(ConsoleLogger.prototype, "error")
      .mockImplementation(() => undefined);
    new ProductionLogger().error(
      JSON.stringify({
        event: "gmail.sync.failed",
        errorType: "Error",
        targetId: "account-1",
        reason: "SYNTHETIC_SECRET",
        authorization: "Bearer SYNTHETIC_SECRET",
        stack: "SYNTHETIC_SECRET",
      }),
    );
    expect(JSON.parse(output.mock.calls[0][0])).toEqual({
      event: "gmail.sync.failed",
      errorType: "Error",
      targetId: "account-1",
    });
  });
});
