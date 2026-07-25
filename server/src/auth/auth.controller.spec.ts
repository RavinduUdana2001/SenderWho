import { AuthController, oauthResultPage } from "./auth.controller";
import { AuthService } from "./auth.service";

describe("AuthController OAuth browser result", () => {
  it("renders a branded page and records a denied Google authorization", async () => {
    const failOAuthSession = jest.fn().mockResolvedValue(undefined);
    const controller = new AuthController({
      failOAuthSession,
    } as unknown as AuthService);

    const page = await controller.handleGoogleCallback(
      undefined,
      "signed-state",
      "access_denied",
    );

    expect(failOAuthSession).toHaveBeenCalledWith(
      "signed-state",
      "access_denied",
    );
    expect(page).toContain("Connection not completed");
    expect(page).toContain("Open SenderWho app");
    expect(page).toContain("senderwho://oauth/callback?status=failed");
    expect(page).not.toContain("BadRequestException");
  });

  it("escapes provider data in the result page", () => {
    const page = oauthResultPage(
      true,
      "Gmail connected",
      '<script>alert("x")</script>',
    );

    expect(page).toContain("&lt;script&gt;");
    expect(page).not.toContain('<script>alert("x")</script>');
    expect(page).toContain("Content-Security-Policy");
    expect(page).toContain('window.location.replace("senderwho://oauth/callback');
    expect(page).toContain("Opening SenderWho");
    expect(page).toContain("senderwho://oauth/callback?status=success");
  });
});
