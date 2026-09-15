import { ConfigService } from "@nestjs/config";
import { PublicSiteController } from "./public-site.controller";
import { escapeHtml } from "./public-site.pages";

describe("PublicSiteController", () => {
  const controller = new PublicSiteController(
    new ConfigService({
      publicSite: {
        legalName: "SenderWho Labs",
        supportEmail: "senderwho.app@gmail.com",
        effectiveDate: "2026-08-01",
      },
    }),
  );

  it("renders all required public pages as complete HTML documents", () => {
    for (const page of [
      controller.home(),
      controller.privacy(),
      controller.terms(),
      controller.support(),
      controller.deleteAccount(),
    ]) {
      expect(page.startsWith("<!doctype html>")).toBe(true);
      expect(page).toContain('name="viewport"');
      expect(page).toContain('href="/privacy"');
      expect(page).toContain('href="/terms"');
      expect(page).toContain('href="/support"');
      expect(page).toContain('href="/delete-account"');
    }
  });

  it("publishes accurate privacy, support, and deletion information", () => {
    expect(controller.privacy()).toContain(
      "does not save the full body or attachment content",
    );
    expect(controller.privacy()).toContain(
      "Google API and Yahoo data limited use",
    );
    expect(controller.privacy()).toContain("We do not sell mailbox data");
    expect(controller.privacy()).toContain("August 1, 2026");
    expect(controller.support()).toContain("senderwho.app@gmail.com");
    expect(controller.deleteAccount()).toContain("Delete SenderWho account");
    expect(controller.deleteAccount()).toContain(
      "does not delete the original messages",
    );
  });

  it("publishes an exact app identity and explicit purpose for OAuth review", () => {
    const home = controller.home();

    expect(home).toContain('name="application-name" content="SenderWho"');
    expect(home).toContain(
      '<span class="app-name">SenderWho</span> helps you understand and manage your inbox.',
    );
    expect(home).toContain("What SenderWho does");
    expect(home).toContain("Why SenderWho requests Gmail permission");
    expect(home).toContain("uses Google OAuth");
    expect(home).toContain("perform only the read, archive, restore, Trash");
    expect(home).toContain(
      "does not ask for a Google password, sell Google user data",
    );
  });

  it("escapes configured values before inserting them into HTML", () => {
    expect(escapeHtml(`<script>alert("x")</script>`)).toBe(
      "&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;",
    );
  });
});
