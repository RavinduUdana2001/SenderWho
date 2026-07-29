import { ConfigService } from "@nestjs/config";
import { PublicSiteController } from "./public-site.controller";
import { escapeHtml } from "./public-site.pages";

describe("PublicSiteController", () => {
  const controller = new PublicSiteController(
    new ConfigService({
      publicSite: {
        legalName: "SenderWho Labs",
        supportEmail: "help@senderwho.com",
        effectiveDate: "2026-07-29",
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
      "We do not sell personal information",
    );
    expect(controller.privacy()).toContain("July 29, 2026");
    expect(controller.support()).toContain("help@senderwho.com");
    expect(controller.deleteAccount()).toContain("Delete SenderWho account");
    expect(controller.deleteAccount()).toContain(
      "does not delete the original messages",
    );
  });

  it("escapes configured values before inserting them into HTML", () => {
    expect(escapeHtml(`<script>alert("x")</script>`)).toBe(
      "&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;",
    );
  });
});
