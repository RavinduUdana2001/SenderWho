import "reflect-metadata";
import { RECENT_AUTH_MAX_AGE_SECONDS_KEY } from "../auth/require-recent-auth.decorator";
import { UnsubscribeController } from "./unsubscribe.controller";

describe("UnsubscribeController authentication policy", () => {
  it.each(["createJob", "createJobs"] as const)(
    "%s requires a valid app session without forcing Google reauthentication",
    (method) => {
      expect(
        Reflect.getMetadata(
          RECENT_AUTH_MAX_AGE_SECONDS_KEY,
          UnsubscribeController.prototype[method],
        ),
      ).toBeUndefined();
    },
  );
});
