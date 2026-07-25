import { getGoogleAccountRecoveryAction } from "./google-account-recovery";

describe("getGoogleAccountRecoveryAction", () => {
  it("distinguishes retry, reconnect, and Google configuration failures", () => {
    expect(getGoogleAccountRecoveryAction("READY", null)).toBe("NONE");
    expect(getGoogleAccountRecoveryAction("FAILED", "Network timeout")).toBe(
      "RETRY",
    );
    expect(
      getGoogleAccountRecoveryAction(
        "DISCONNECTED",
        "Google access was revoked. Reconnect the account.",
      ),
    ).toBe("RECONNECT");
    expect(
      getGoogleAccountRecoveryAction(
        "FAILED",
        "The SenderWho Google OAuth client is disabled.",
      ),
    ).toBe("CONFIGURE_GOOGLE");
    expect(
      getGoogleAccountRecoveryAction(
        "FAILED",
        "Unsupported state or unable to authenticate data",
      ),
    ).toBe("RECONNECT");
  });
});
