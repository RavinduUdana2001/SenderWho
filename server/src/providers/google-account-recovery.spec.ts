import {
  getEmailAccountRecoveryAction,
  getGoogleAccountRecoveryAction,
} from "./google-account-recovery";

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

  it("uses provider-neutral recovery actions for Yahoo accounts", () => {
    expect(
      getEmailAccountRecoveryAction(
        "YAHOO",
        "DISCONNECTED",
        "Yahoo authorization expired. Reconnect Yahoo Mail.",
      ),
    ).toBe("RECONNECT");
    expect(
      getEmailAccountRecoveryAction("YAHOO", "FAILED", "Temporary timeout"),
    ).toBe("RETRY");
    expect(
      getEmailAccountRecoveryAction(
        "YAHOO",
        "FAILED",
        "OAuth client is disabled",
      ),
    ).toBe("RETRY");
  });

  it("offers reconnect for legacy 403 failures and separates quota, policy and configuration", () => {
    expect(
      getGoogleAccountRecoveryAction(
        "FAILED",
        "Gmail batch item failed with status 403.",
      ),
    ).toBe("RECONNECT");
    expect(
      getGoogleAccountRecoveryAction(
        "FAILED",
        "Gmail is temporarily limiting mailbox scans.",
      ),
    ).toBe("RETRY");
    expect(
      getGoogleAccountRecoveryAction(
        "FAILED",
        "Your Google Workspace administrator does not allow SenderWho.",
      ),
    ).toBe("CONTACT_ADMIN");
    expect(
      getGoogleAccountRecoveryAction(
        "FAILED",
        "The SenderWho Gmail API is not enabled.",
      ),
    ).toBe("CONFIGURE_GOOGLE");
  });
});
