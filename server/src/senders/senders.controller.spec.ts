import "reflect-metadata";
import { RECENT_AUTH_MAX_AGE_SECONDS_KEY } from "../auth/require-recent-auth.decorator";
import { SendersController } from "./senders.controller";

describe("SendersController authentication policy", () => {
  it("allows trust changes with a valid app session without Google reauthentication", () => {
    expect(
      Reflect.getMetadata(
        RECENT_AUTH_MAX_AGE_SECONDS_KEY,
        SendersController.prototype.trust,
      ),
    ).toBeUndefined();
  });

  it("keeps recent authentication protection on blocking", () => {
    expect(
      Reflect.getMetadata(
        RECENT_AUTH_MAX_AGE_SECONDS_KEY,
        SendersController.prototype.block,
      ),
    ).toBe(10 * 60);
  });
});
