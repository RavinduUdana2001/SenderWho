import "reflect-metadata";
import { CleanupController } from "../cleanup/cleanup.controller";
import { EmailAccountsController } from "../email-accounts/email-accounts.controller";
import { EmailMessagesController } from "../email-messages/email-messages.controller";
import { SecurityAlertsController } from "../security-alerts/security-alerts.controller";
import { UsersController } from "../users/users.controller";
import { RECENT_AUTH_MAX_AGE_SECONDS_KEY } from "./require-recent-auth.decorator";
import { AuthController } from "./auth.controller";

describe("persistent app-session policy", () => {
  it.each([
    ["cleanup", CleanupController.prototype.createJob],
    ["trash", EmailMessagesController.prototype.trash],
    ["resolve alert", SecurityAlertsController.prototype.resolve],
    ["dismiss alert", SecurityAlertsController.prototype.dismiss],
    ["disconnect account", EmailAccountsController.prototype.disconnect],
    ["export data", UsersController.prototype.exportData],
    ["revoke session", AuthController.prototype.revokeSession],
    ["revoke all sessions", AuthController.prototype.revokeAllSessions],
  ])("%s uses the valid app session without provider re-login", (_, method) => {
    expect(
      Reflect.getMetadata(RECENT_AUTH_MAX_AGE_SECONDS_KEY, method),
    ).toBeUndefined();
  });

  it("requires fresh authentication only for permanent account deletion", () => {
    expect(
      Reflect.getMetadata(
        RECENT_AUTH_MAX_AGE_SECONDS_KEY,
        UsersController.prototype.deleteAccount,
      ),
    ).toBe(10 * 60);
  });
});
