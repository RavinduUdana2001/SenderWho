import {
  Body,
  Controller,
  Get,
  Header,
  HttpCode,
  Delete,
  Param,
  Post,
  Query,
  Req,
} from "@nestjs/common";
import type { Request } from "express";
import { Throttle } from "@nestjs/throttler";
import { CurrentUser } from "./current-user.decorator";
import { ExchangeOAuthSessionDto } from "./dto/exchange-oauth-session.dto";
import { RefreshSessionDto } from "./dto/refresh-session.dto";
import { StartOAuthDto } from "./dto/start-oauth.dto";
import { Public } from "./public.decorator";
import { AuthService, SessionContext } from "./auth.service";
import { Idempotent } from "../common/security/idempotent.decorator";

@Controller("auth")
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Get("providers")
  @Public()
  @Throttle({ default: { limit: 60, ttl: 60_000, blockDuration: 60_000 } })
  availableProviders() {
    return this.authService.availableProviders();
  }

  @Post("oauth/google/start")
  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000, blockDuration: 60_000 } })
  startGoogleOAuth(@Body() body?: StartOAuthDto) {
    return this.authService.startOAuth("google", {
      loginHint: body?.loginHint,
    });
  }

  @Post("oauth/yahoo/start")
  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000, blockDuration: 60_000 } })
  startYahooOAuth() {
    return this.authService.startOAuth("yahoo");
  }

  @Post("reauth/google/start")
  @Throttle({ default: { limit: 5, ttl: 60_000, blockDuration: 120_000 } })
  startGoogleReauthentication(
    @CurrentUser("id") userId: string,
    @CurrentUser("sessionId") sessionId: string,
  ) {
    return this.authService.startReauthentication(userId, sessionId);
  }

  @Get("oauth/google/callback")
  @Public()
  @Throttle({ default: { limit: 20, ttl: 60_000, blockDuration: 60_000 } })
  @Header("Content-Type", "text/html; charset=utf-8")
  async handleGoogleCallback(
    @Query("code") code?: string,
    @Query("state") state?: string,
    @Query("error") error?: string,
  ) {
    if (error) {
      await this.authService.failOAuthSession(state, error);
      return oauthResultPage(
        false,
        "Connection not completed",
        error === "access_denied"
          ? "Google access was not granted. Return to SenderWho and try again when you are ready."
          : "Google could not complete authorization. Return to SenderWho and try again.",
      );
    }
    if (!code) {
      await this.authService.failOAuthSession(
        state,
        "Google authorization code is missing.",
      );
      return oauthResultPage(
        false,
        "Connection not completed",
        "Google did not return an authorization code. Return to SenderWho and try again.",
      );
    }

    try {
      const result = await this.authService.handleOAuthCallback(
        "google",
        code,
        state,
      );
      return oauthResultPage(
        true,
        result.reauthenticated ? "Identity verified" : "Gmail connected",
        result.reauthenticated
          ? `Recent authentication for ${result.emailAddress} is complete. Return to SenderWho to continue.`
          : `${result.emailAddress} is now connected. Return to SenderWho to continue.`,
      );
    } catch {
      return oauthResultPage(
        false,
        "Could not connect Gmail",
        "SenderWho could not finish the secure Google connection. Return to the app for details and try again.",
      );
    }
  }

  @Get("oauth/yahoo/callback")
  @Public()
  @Throttle({ default: { limit: 20, ttl: 60_000, blockDuration: 60_000 } })
  @Header("Content-Type", "text/html; charset=utf-8")
  async handleYahooCallback(
    @Query("code") code?: string,
    @Query("state") state?: string,
    @Query("error") error?: string,
  ) {
    if (error) {
      await this.authService.failOAuthSession(state, error);
      return oauthResultPage(
        false,
        "Connection not completed",
        error === "access_denied"
          ? "Yahoo access was not granted. Return to SenderWho and try again when you are ready."
          : "Yahoo could not complete authorization. Return to SenderWho and try again.",
      );
    }
    if (!code) {
      await this.authService.failOAuthSession(
        state,
        "Yahoo authorization code is missing.",
      );
      return oauthResultPage(
        false,
        "Connection not completed",
        "Yahoo did not return an authorization code. Return to SenderWho and try again.",
      );
    }
    try {
      const result = await this.authService.handleOAuthCallback(
        "yahoo",
        code,
        state,
      );
      return oauthResultPage(
        true,
        "Yahoo Mail connected",
        `${result.emailAddress} is now connected. Return to SenderWho to continue.`,
      );
    } catch {
      return oauthResultPage(
        false,
        "Could not connect Yahoo Mail",
        "SenderWho could not finish the secure Yahoo connection. Return to the app for details and try again.",
      );
    }
  }

  @Post("oauth/session/exchange")
  @Public()
  @HttpCode(200)
  @Throttle({ default: { limit: 40, ttl: 60_000, blockDuration: 60_000 } })
  exchangeOAuthSession(
    @Body() body: ExchangeOAuthSessionDto,
    @Req() request: Request,
  ) {
    return this.authService.exchangeOAuthSession(
      body.sessionId,
      body.sessionSecret,
      sessionContext(request),
    );
  }

  @Post("refresh")
  @Public()
  @HttpCode(200)
  @Throttle({ default: { limit: 20, ttl: 60_000, blockDuration: 60_000 } })
  refresh(@Body() body: RefreshSessionDto, @Req() request: Request) {
    return this.authService.refreshSession(
      body.refreshToken,
      sessionContext(request),
    );
  }

  @Get("me")
  getMe(@CurrentUser("id") userId: string) {
    return this.authService.getMe(userId);
  }

  @Get("sessions")
  listSessions(
    @CurrentUser("id") userId: string,
    @CurrentUser("sessionId") sessionId: string,
  ) {
    return this.authService.listSessions(userId, sessionId);
  }

  @Delete("sessions/:id")
  @Idempotent("auth.session.revoke")
  revokeSession(
    @CurrentUser("id") userId: string,
    @CurrentUser("sessionId") currentSessionId: string,
    @Param("id") sessionId: string,
  ) {
    return this.authService.revokeSession(userId, sessionId, currentSessionId);
  }

  @Post("sessions/revoke-all")
  @Idempotent("auth.sessions.revoke-all")
  revokeAllSessions(@CurrentUser("id") userId: string) {
    return this.authService.revokeAllSessions(userId);
  }

  @Post("logout")
  @Public()
  @HttpCode(200)
  @Throttle({ default: { limit: 10, ttl: 60_000, blockDuration: 60_000 } })
  logout(@Body() body: RefreshSessionDto) {
    return this.authService.logout(body.refreshToken);
  }
}

function sessionContext(request: Request): SessionContext {
  const deviceId = request.header("x-senderwho-device-id") ?? undefined;
  const deviceName = request.header("x-senderwho-device-name") ?? undefined;
  return {
    deviceId:
      deviceId && /^[A-Za-z0-9_-]{20,200}$/.test(deviceId)
        ? deviceId
        : undefined,
    deviceName,
    ipAddress: request.ip,
    userAgent: request.header("user-agent") ?? undefined,
  };
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>'"]/g, (character) => {
    const entities: Record<string, string> = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      "'": "&#39;",
      '"': "&quot;",
    };
    return entities[character];
  });
}

export function oauthResultPage(
  success: boolean,
  title: string,
  message: string,
) {
  const safeTitle = escapeHtml(title);
  const safeMessage = escapeHtml(message);
  const color = success ? "#16b978" : "#f0445e";
  const symbol = success ? "✓" : "!";
  const appUrl = `senderwho://oauth/callback?status=${success ? "success" : "failed"}`;
  const browserStatus = success
    ? "Opening SenderWho…"
    : "Return to SenderWho for details";
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-senderwho-oauth'; base-uri 'none'; form-action 'none'">
    <meta http-equiv="refresh" content="1;url=${appUrl}">
    <title>SenderWho</title>
    <script nonce="senderwho-oauth">
      (() => {
        const openApp = () => window.location.replace("${appUrl}");
        window.addEventListener("pageshow", () => window.setTimeout(openApp, 120));
        window.addEventListener("focus", () => window.setTimeout(openApp, 120));
      })();
    </script>
  </head>
  <body style="margin:0;min-height:100vh;display:grid;place-items:center;background:#f6f8fc;font-family:system-ui,-apple-system,sans-serif;color:#111827">
    <main style="box-sizing:border-box;width:min(420px,calc(100% - 32px));padding:32px 24px;background:#fff;border:1px solid #dce3ee;border-radius:22px;text-align:center">
      <div style="display:grid;place-items:center;width:58px;height:58px;margin:0 auto 20px;border-radius:18px;background:${color}18;color:${color};font-size:30px;font-weight:800">${symbol}</div>
      <h1 style="margin:0 0 10px;font-size:26px;line-height:1.2">${safeTitle}</h1>
      <p style="margin:0;color:#64718b;font-size:15px;line-height:1.55">${safeMessage}</p>
      <p role="status" style="margin:16px 0 0;color:#334155;font-size:14px;font-weight:650">${browserStatus}</p>
      <a href="${appUrl}" style="box-sizing:border-box;display:block;margin:16px 0 0;padding:13px 18px;border-radius:12px;background:#3b82f6;color:#fff;text-decoration:none;font-size:15px;font-weight:750">Open SenderWho app</a>
      <p style="margin:12px 0 0;color:#64718b;font-size:12px">If the app does not open automatically, tap the button above.</p>
    </main>
  </body>
</html>`;
}
