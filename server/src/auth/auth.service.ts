import {
  BadGatewayException,
  BadRequestException,
  ConflictException,
  GoneException,
  Injectable,
  Logger,
  NotImplementedException,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { JwtService } from "@nestjs/jwt";
import {
  EmailProvider,
  OAuthLoginStatus,
  Prisma,
  SyncStatus,
} from "@prisma/client";
import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import {
  OAUTH_PKCE_CONTEXT,
  TokenEncryptionService,
  googleProviderTokenContext,
  yahooProviderTokenContext,
} from "../common/security/token-encryption.service";
import { PrismaService } from "../database/prisma.service";
import { InboxJobsService } from "../jobs/inbox-jobs.service";
import { GmailClient } from "../providers/gmail/gmail.client";
import { YahooImapClient } from "../providers/yahoo/yahoo-imap.client";
import { AccessTokenPayload } from "./auth-user.interface";

type OAuthProvider = "google" | "microsoft" | "yahoo";

interface GoogleTokenResponse {
  access_token?: string;
  expires_in?: number;
  refresh_token?: string;
  id_token?: string;
  scope?: string;
  token_type?: string;
}

interface GoogleIdTokenClaims {
  sub?: string;
  email?: string;
  email_verified?: string | boolean;
  aud?: string;
  iss?: string;
  exp?: string;
  iat?: string;
  nonce?: string;
}

interface YahooTokenResponse {
  access_token?: string;
  expires_in?: number;
  refresh_token?: string;
  id_token?: string;
  scope?: string;
  token_type?: string;
}

interface YahooUserInfo {
  sub?: string;
  email?: string;
  email_verified?: boolean;
  name?: string;
  picture?: string;
}

interface OAuthState {
  purpose?: string;
  provider?: OAuthProvider;
  loginSessionId?: string;
}

const GOOGLE_SCOPES = [
  "openid",
  "https://www.googleapis.com/auth/userinfo.email",
  "https://www.googleapis.com/auth/gmail.modify",
];
const YAHOO_SCOPES = ["openid", "email", "profile", "mail-r"];
const LOGIN_SESSION_TTL_MS = 10 * 60 * 1_000;
const OIDC_CLOCK_SKEW_SECONDS = 60;

export interface SessionContext {
  deviceId?: string;
  deviceName?: string;
  ipAddress?: string;
  userAgent?: string;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
    private readonly gmailClient: GmailClient,
    private readonly tokenEncryption: TokenEncryptionService,
    private readonly inboxJobs: InboxJobsService,
    private readonly yahooImap?: YahooImapClient,
  ) {}

  async connectYahooImap(
    rawEmail: string,
    rawAppPassword: string,
    context: SessionContext = {},
  ) {
    if (!this.yahooImap) {
      throw new ServiceUnavailableException(
        "Yahoo Mail connection is unavailable.",
      );
    }
    const email = rawEmail.trim().toLowerCase();
    const appPassword = rawAppPassword.replace(/\s+/g, "");
    if (appPassword.length < 12) {
      throw new BadRequestException(
        "Enter the generated Yahoo app password, not your normal password.",
      );
    }
    await this.yahooImap.verify(email, appPassword);

    let user = await this.prisma.user.findFirst({
      where: { email, deletedAt: null },
      select: { id: true, email: true },
    });
    if (!user) {
      user = await this.prisma.user.create({
        data: { email },
        select: { id: true, email: true },
      });
    }
    const existingAccount = await this.prisma.emailAccount.findFirst({
      where: { provider: EmailProvider.YAHOO, emailAddress: email },
      select: { id: true, providerAccountId: true },
    });
    const providerAccountId = existingAccount?.providerAccountId ?? email;
    const encryptedPassword = this.tokenEncryption.encrypt(
      appPassword,
      yahooProviderTokenContext(providerAccountId),
    );
    const account = existingAccount
      ? await this.prisma.emailAccount.update({
          where: { id: existingAccount.id },
          data: {
            userId: user.id,
            emailAddress: email,
            accessTokenEncrypted: null,
            refreshTokenEncrypted: encryptedPassword,
            tokenExpiresAt: null,
            scopes: ["imap"],
            syncStatus: SyncStatus.PENDING,
            lastSyncError: null,
            backfillPageToken: null,
            backfillComplete: false,
            backfillProcessed: 0,
          },
        })
      : await this.prisma.emailAccount.create({
          data: {
            userId: user.id,
            provider: EmailProvider.YAHOO,
            providerAccountId,
            emailAddress: email,
            refreshTokenEncrypted: encryptedPassword,
            scopes: ["imap"],
            syncStatus: SyncStatus.PENDING,
          },
        });
    await this.inboxJobs.enqueueScan(account.id);
    await this.safeAudit({
      userId: user.id,
      action: "email_account.connected",
      targetType: "EmailAccount",
      targetId: account.id,
      metadata: { provider: EmailProvider.YAHOO, method: "IMAP_APP_PASSWORD" },
    });
    return this.createAuthenticatedSession(user, context);
  }

  async startOAuth(
    provider: OAuthProvider,
    options: {
      purpose?: "LOGIN" | "REAUTH";
      userId?: string;
      appSessionId?: string;
      loginHint?: string;
    } = {},
  ) {
    if (provider !== "google" && provider !== "yahoo") {
      throw new NotImplementedException(
        `${provider} OAuth is not configured yet.`,
      );
    }

    const providerConfig =
      provider === "google" ? this.getGoogleConfig() : this.getYahooConfig();
    const sessionSecret = this.randomToken(32);
    const pkceVerifier = this.randomToken(48);
    const pkceChallenge = createHash("sha256")
      .update(pkceVerifier)
      .digest("base64url");
    const nonce = this.randomToken(32);
    const expiresAt = new Date(Date.now() + LOGIN_SESSION_TTL_MS);
    await this.prisma.oAuthLoginSession.deleteMany({
      where: { expiresAt: { lt: new Date() } },
    });
    const loginSession = await this.prisma.oAuthLoginSession.create({
      data: {
        secretHash: this.hashToken(sessionSecret),
        provider:
          provider === "google" ? EmailProvider.GOOGLE : EmailProvider.YAHOO,
        purpose: options.purpose ?? "LOGIN",
        userId: options.userId,
        appSessionId: options.appSessionId,
        pkceVerifierEncrypted: this.tokenEncryption.encrypt(
          pkceVerifier,
          OAUTH_PKCE_CONTEXT,
        ),
        nonceHash: this.hashToken(nonce),
        status: OAuthLoginStatus.PENDING,
        expiresAt,
      },
      select: { id: true },
    });
    const state = await this.jwtService.signAsync(
      {
        purpose:
          options.purpose === "REAUTH"
            ? "email-account-reauth"
            : "email-account-oauth",
        provider,
        loginSessionId: loginSession.id,
      } satisfies OAuthState,
      { expiresIn: "10m" },
    );
    const authorizationUrl = new URL(
      provider === "google"
        ? "https://accounts.google.com/o/oauth2/v2/auth"
        : "https://api.login.yahoo.com/oauth2/request_auth",
    );

    authorizationUrl.searchParams.set("client_id", providerConfig.clientId);
    authorizationUrl.searchParams.set(
      "redirect_uri",
      providerConfig.callbackUrl,
    );
    authorizationUrl.searchParams.set("response_type", "code");
    authorizationUrl.searchParams.set(
      "scope",
      (provider === "google" ? GOOGLE_SCOPES : YAHOO_SCOPES).join(" "),
    );
    // Do not force the consent screen for returning users. Google will still
    // request consent on the first authorization or whenever scopes change.
    if (provider === "google") {
      authorizationUrl.searchParams.set("access_type", "offline");
      authorizationUrl.searchParams.set("include_granted_scopes", "true");
      if (options.loginHint) {
        authorizationUrl.searchParams.set("login_hint", options.loginHint);
      } else {
        authorizationUrl.searchParams.set("prompt", "select_account");
      }
    }
    authorizationUrl.searchParams.set("state", state);
    authorizationUrl.searchParams.set("nonce", nonce);
    authorizationUrl.searchParams.set("code_challenge", pkceChallenge);
    authorizationUrl.searchParams.set("code_challenge_method", "S256");

    return {
      provider,
      authorizationUrl: authorizationUrl.toString(),
      loginSessionId: loginSession.id,
      loginSessionSecret: sessionSecret,
      expiresAt: expiresAt.toISOString(),
    };
  }

  async startReauthentication(userId: string, appSessionId: string) {
    const session = await this.prisma.appSession.findFirst({
      where: {
        id: appSessionId,
        userId,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      select: { id: true },
    });
    if (!session) {
      throw new UnauthorizedException("The current app session is invalid.");
    }
    return this.startOAuth("google", {
      purpose: "REAUTH",
      userId,
      appSessionId: session.id,
    });
  }

  async handleOAuthCallback(
    provider: OAuthProvider,
    code: string,
    state?: string,
  ) {
    if (provider !== "google" && provider !== "yahoo") {
      throw new NotImplementedException(
        `${provider} OAuth is not configured yet.`,
      );
    }

    const loginSession = await this.verifyState(provider, state);
    if (provider === "yahoo") {
      return this.handleYahooOAuthCallback(code, loginSession);
    }
    try {
      const google = this.getGoogleConfig();
      const tokens = await this.exchangeGoogleCode(
        code,
        google,
        this.tokenEncryption.decrypt(
          loginSession.pkceVerifierEncrypted,
          OAUTH_PKCE_CONTEXT,
        ),
      );

      if (!tokens.access_token) {
        throw new BadGatewayException(
          "Google did not return an OAuth access token.",
        );
      }

      if (!tokens.id_token) {
        throw new BadGatewayException("Google did not return an ID token.");
      }
      const [gmailProfile, identity] = await Promise.all([
        this.gmailClient.getProfile(tokens.access_token),
        this.validateGoogleIdToken(
          tokens.id_token,
          google.clientId,
          loginSession.nonceHash,
        ),
      ]);
      const emailAddress = identity.email ?? gmailProfile.emailAddress;
      const providerAccountId = identity.sub;

      if (!emailAddress || !providerAccountId) {
        throw new BadGatewayException(
          "Google did not return the connected account identity.",
        );
      }
      if (
        gmailProfile.emailAddress?.trim().toLowerCase() !==
        emailAddress.trim().toLowerCase()
      ) {
        throw new UnauthorizedException(
          "Google identity and Gmail account do not match.",
        );
      }
      const scopes = (tokens.scope ?? "").split(" ").filter(Boolean);
      const missingScopes = GOOGLE_SCOPES.filter(
        (requiredScope) => !scopes.includes(requiredScope),
      );
      if (missingScopes.length > 0) {
        throw new UnauthorizedException(
          "Google did not grant all required SenderWho permissions.",
        );
      }

      if (this.prisma.mockDataEnabled) {
        return {
          success: true,
          provider,
          emailAddress,
          emailAccountId: `google:${providerAccountId}`,
          persisted: false,
          reauthenticated: loginSession.purpose === "REAUTH",
        };
      }

      const existingAccount = await this.prisma.emailAccount.findUnique({
        where: {
          provider_providerAccountId: {
            provider: EmailProvider.GOOGLE,
            providerAccountId,
          },
        },
        select: { refreshTokenEncrypted: true, userId: true },
      });

      if (
        loginSession.purpose === "REAUTH" &&
        (!loginSession.userId ||
          existingAccount?.userId !== loginSession.userId)
      ) {
        throw new UnauthorizedException(
          "Reauthentication must use the currently signed-in Google account.",
        );
      }

      if (loginSession.purpose === "REAUTH") {
        if (!loginSession.appSessionId) {
          throw new UnauthorizedException(
            "Reauthentication is not bound to an app session.",
          );
        }
        const currentSession = await this.prisma.appSession.findFirst({
          where: {
            id: loginSession.appSessionId,
            userId: loginSession.userId!,
            revokedAt: null,
            expiresAt: { gt: new Date() },
          },
          select: { id: true },
        });
        if (!currentSession) {
          throw new UnauthorizedException(
            "The app session used for reauthentication is no longer active.",
          );
        }
        await this.prisma.oAuthLoginSession.update({
          where: { id: loginSession.id },
          data: { status: OAuthLoginStatus.COMPLETED },
        });
        return {
          success: true,
          provider,
          emailAddress,
          emailAccountId: null,
          persisted: false,
          reauthenticated: true,
        };
      }

      if (!tokens.refresh_token && !existingAccount?.refreshTokenEncrypted) {
        throw new BadGatewayException(
          "Google did not return offline access. Revoke SenderWho access and connect again.",
        );
      }

      const user = await this.resolveGoogleUser(
        providerAccountId,
        emailAddress,
        loginSession.purpose === "REAUTH"
          ? loginSession.userId!
          : existingAccount?.userId,
      );
      const accessTokenEncrypted = this.tokenEncryption.encrypt(
        tokens.access_token,
        googleProviderTokenContext(providerAccountId),
      );
      const refreshTokenEncrypted = tokens.refresh_token
        ? this.tokenEncryption.encrypt(
            tokens.refresh_token,
            googleProviderTokenContext(providerAccountId),
          )
        : undefined;
      const tokenExpiresAt = tokens.expires_in
        ? new Date(Date.now() + tokens.expires_in * 1_000)
        : null;
      const emailAccount = await this.prisma.emailAccount.upsert({
        where: {
          provider_providerAccountId: {
            provider: EmailProvider.GOOGLE,
            providerAccountId,
          },
        },
        create: {
          userId: user.id,
          provider:
            provider === "google" ? EmailProvider.GOOGLE : EmailProvider.YAHOO,
          providerAccountId,
          emailAddress,
          accessTokenEncrypted,
          refreshTokenEncrypted,
          tokenExpiresAt,
          scopes,
          syncStatus: SyncStatus.PENDING,
        },
        update: {
          userId: user.id,
          emailAddress,
          accessTokenEncrypted,
          ...(refreshTokenEncrypted ? { refreshTokenEncrypted } : {}),
          tokenExpiresAt,
          scopes,
          syncStatus: SyncStatus.PENDING,
          lastSyncError: null,
        },
      });

      await this.safeAudit({
        userId: user.id,
        action: "email_account.connected",
        targetType: "EmailAccount",
        targetId: emailAccount.id,
        metadata: { provider: EmailProvider.GOOGLE },
      });

      let syncJob:
        | { jobId?: string; status: "QUEUED" }
        | { status: "FAILED"; error: string };
      try {
        syncJob = await this.inboxJobs.enqueueScan(emailAccount.id);
      } catch {
        await this.prisma.emailAccount.update({
          where: { id: emailAccount.id },
          data: {
            syncStatus: SyncStatus.FAILED,
            lastSyncError: "The initial scan could not be queued.",
          },
        });
        syncJob = {
          status: "FAILED",
          error: "The initial scan could not be queued. Retry from the app.",
        };
      }

      await this.prisma.oAuthLoginSession.update({
        where: { id: loginSession.id },
        data: { userId: user.id, status: OAuthLoginStatus.COMPLETED },
      });

      return {
        success: true,
        provider,
        emailAddress,
        emailAccountId: emailAccount.id,
        persisted: true,
        reauthenticated: false,
        syncJob,
      };
    } catch (error) {
      await this.prisma.oAuthLoginSession.updateMany({
        where: { id: loginSession.id, status: OAuthLoginStatus.PENDING },
        data: {
          status: OAuthLoginStatus.FAILED,
          error: this.safeErrorMessage(error),
        },
      });
      this.logger.warn(
        JSON.stringify({
          event: "oauth.callback.failed",
          provider,
          targetId: loginSession.id,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
      throw error;
    }
  }

  async failOAuthSession(state: string | undefined, reason: string) {
    if (!state) return;
    try {
      const payload = await this.jwtService.verifyAsync<OAuthState>(state);
      if (
        !["email-account-oauth", "email-account-reauth"].includes(
          payload.purpose ?? "",
        ) ||
        !payload.loginSessionId
      ) {
        return;
      }
      await this.prisma.oAuthLoginSession.updateMany({
        where: {
          id: payload.loginSessionId,
          status: OAuthLoginStatus.PENDING,
        },
        data: { status: OAuthLoginStatus.FAILED, error: reason.slice(0, 500) },
      });
    } catch {
      return;
    }
  }

  async exchangeOAuthSession(
    sessionId: string,
    sessionSecret: string,
    context: SessionContext = {},
  ) {
    const loginSession = await this.prisma.oAuthLoginSession.findUnique({
      where: { id: sessionId },
      include: { user: { select: { id: true, email: true } } },
    });
    if (
      !loginSession ||
      !this.matchesHash(sessionSecret, loginSession.secretHash)
    ) {
      throw new UnauthorizedException("The login session is invalid.");
    }
    if (loginSession.expiresAt <= new Date()) {
      throw new GoneException("The login session expired. Sign in again.");
    }
    if (loginSession.status === OAuthLoginStatus.PENDING) {
      return { status: OAuthLoginStatus.PENDING };
    }
    if (loginSession.status === OAuthLoginStatus.FAILED) {
      return {
        status: OAuthLoginStatus.FAILED,
        error: loginSession.error ?? "Google sign-in failed.",
      };
    }
    if (
      loginSession.status === OAuthLoginStatus.EXCHANGED ||
      !loginSession.user
    ) {
      throw new GoneException("This login session was already exchanged.");
    }

    if (loginSession.purpose === "REAUTH") {
      if (!loginSession.appSessionId) {
        throw new UnauthorizedException(
          "Reauthentication is not bound to an app session.",
        );
      }
      const authenticatedAt = new Date();
      const appSession = await this.prisma.$transaction(async (transaction) => {
        const claimed = await transaction.oAuthLoginSession.updateMany({
          where: { id: sessionId, status: OAuthLoginStatus.COMPLETED },
          data: {
            status: OAuthLoginStatus.EXCHANGED,
            exchangedAt: new Date(),
          },
        });
        if (claimed.count !== 1) {
          throw new ConflictException(
            "This reauthentication session was already exchanged.",
          );
        }
        const updated = await transaction.appSession.updateMany({
          where: {
            id: loginSession.appSessionId!,
            userId: loginSession.user!.id,
            revokedAt: null,
            expiresAt: { gt: new Date() },
          },
          data: { authenticatedAt, lastUsedAt: authenticatedAt },
        });
        if (updated.count !== 1) {
          throw new UnauthorizedException(
            "The app session used for reauthentication is no longer active.",
          );
        }
        return { id: loginSession.appSessionId! };
      });
      return this.reauthenticationResponse(
        loginSession.user,
        appSession.id,
        authenticatedAt,
      );
    }

    const refreshToken = this.randomToken(48);
    const refreshExpiresAt = this.refreshExpiresAt();
    const authenticatedAt = new Date();
    const appSession = await this.prisma.$transaction(async (transaction) => {
      const claimed = await transaction.oAuthLoginSession.updateMany({
        where: { id: sessionId, status: OAuthLoginStatus.COMPLETED },
        data: {
          status: OAuthLoginStatus.EXCHANGED,
          exchangedAt: new Date(),
        },
      });
      if (claimed.count !== 1) {
        throw new ConflictException(
          "This login session was already exchanged.",
        );
      }
      return transaction.appSession.create({
        data: {
          userId: loginSession.user!.id,
          familyId: this.randomToken(24),
          tokenHash: this.hashToken(refreshToken),
          expiresAt: refreshExpiresAt,
          authenticatedAt,
          ...this.sessionContextData(context),
        },
        select: { id: true },
      });
    });

    return this.tokenResponse(
      loginSession.user,
      refreshToken,
      refreshExpiresAt,
      appSession.id,
      authenticatedAt,
    );
  }

  async refreshSession(refreshToken: string, context: SessionContext = {}) {
    const tokenHash = this.hashToken(refreshToken);
    const currentSession = await this.prisma.appSession.findUnique({
      where: { tokenHash },
      include: {
        user: { select: { id: true, email: true, deletedAt: true } },
      },
    });
    if (!currentSession || currentSession.expiresAt <= new Date()) {
      throw new UnauthorizedException("The refresh session is invalid.");
    }
    if (currentSession.user.deletedAt) {
      await this.revokeFamily(currentSession.familyId, "USER_DELETED");
      throw new UnauthorizedException("The refresh session is invalid.");
    }
    if (currentSession.revokedAt) {
      await this.revokeFamily(currentSession.familyId, "TOKEN_REUSE");
      await this.writeSecurityAudit(
        currentSession.user.id,
        "auth.refresh_token_reuse",
        currentSession.id,
        context,
      );
      throw new UnauthorizedException(
        "The refresh token was already used. This session family was revoked.",
      );
    }

    const nextRefreshToken = this.randomToken(48);
    const nextExpiresAt = this.refreshExpiresAt();
    const nextSession = await this.prisma.$transaction(async (transaction) => {
      const rotated = await transaction.appSession.updateMany({
        where: {
          id: currentSession.id,
          revokedAt: null,
          expiresAt: { gt: new Date() },
        },
        data: {
          revokedAt: new Date(),
          revocationReason: "ROTATED",
          lastUsedAt: new Date(),
        },
      });
      if (rotated.count !== 1) {
        return null;
      }
      const created = await transaction.appSession.create({
        data: {
          userId: currentSession.user.id,
          familyId: currentSession.familyId,
          parentId: currentSession.id,
          tokenHash: this.hashToken(nextRefreshToken),
          expiresAt: nextExpiresAt,
          authenticatedAt: currentSession.authenticatedAt,
          ...this.sessionContextData(context),
        },
        select: { id: true },
      });
      await transaction.appSession.update({
        where: { id: currentSession.id },
        data: { replacedById: created.id },
      });
      return created;
    });
    if (!nextSession) {
      await this.revokeFamily(currentSession.familyId, "TOKEN_REUSE");
      await this.writeSecurityAudit(
        currentSession.user.id,
        "auth.refresh_token_reuse",
        currentSession.id,
        context,
      );
      throw new UnauthorizedException(
        "The refresh token was already used. This session family was revoked.",
      );
    }

    return this.tokenResponse(
      currentSession.user,
      nextRefreshToken,
      nextExpiresAt,
      nextSession.id,
      currentSession.authenticatedAt,
    );
  }

  async logout(refreshToken: string) {
    const result = await this.prisma.appSession.updateMany({
      where: {
        tokenHash: this.hashToken(refreshToken),
        revokedAt: null,
      },
      data: { revokedAt: new Date(), revocationReason: "LOGOUT" },
    });
    return { success: true, refreshTokenRevoked: result.count === 1 };
  }

  async listSessions(userId: string, currentSessionId: string) {
    const sessions = await this.prisma.appSession.findMany({
      where: {
        userId,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        deviceName: true,
        userAgent: true,
        ipAddress: true,
        authenticatedAt: true,
        lastUsedAt: true,
        createdAt: true,
        expiresAt: true,
      },
    });
    return {
      items: sessions.map((session) => ({
        ...session,
        current: session.id === currentSessionId,
      })),
    };
  }

  async revokeSession(
    userId: string,
    sessionId: string,
    currentSessionId: string,
  ) {
    const result = await this.prisma.appSession.updateMany({
      where: { id: sessionId, userId, revokedAt: null },
      data: { revokedAt: new Date(), revocationReason: "REMOTE_REVOKE" },
    });
    if (result.count !== 1) {
      throw new BadRequestException("The session is unavailable.");
    }
    await this.writeSecurityAudit(
      userId,
      "auth.session_revoked",
      sessionId,
      {},
    );
    return { success: true, revokedCurrent: sessionId === currentSessionId };
  }

  async revokeAllSessions(userId: string) {
    const result = await this.prisma.appSession.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date(), revocationReason: "REVOKE_ALL" },
    });
    await this.writeSecurityAudit(
      userId,
      "auth.all_sessions_revoked",
      undefined,
      {},
    );
    return { success: true, revokedSessions: result.count };
  }

  getMe(userId: string) {
    return this.prisma.user.findFirst({
      where: { id: userId, deletedAt: null },
      select: { id: true, email: true, displayName: true, avatarUrl: true },
    });
  }

  private sessionContextData(context: SessionContext) {
    const deviceId = context.deviceId?.trim();
    return {
      deviceIdHash: deviceId ? this.hashToken(deviceId) : undefined,
      deviceName: context.deviceName?.trim().slice(0, 120) || undefined,
      ipAddress: context.ipAddress?.trim().slice(0, 64) || undefined,
      userAgent: context.userAgent?.trim().slice(0, 500) || undefined,
    };
  }

  private async revokeFamily(familyId: string, reason: string) {
    await this.prisma.appSession.updateMany({
      where: { familyId, revokedAt: null },
      data: { revokedAt: new Date(), revocationReason: reason.slice(0, 64) },
    });
  }

  private async writeSecurityAudit(
    userId: string,
    action: string,
    targetId: string | undefined,
    context: SessionContext,
  ) {
    await this.safeAudit({
      userId,
      action,
      targetType: "AppSession",
      targetId,
      ipAddress: context.ipAddress?.slice(0, 64),
      userAgent: context.userAgent?.slice(0, 500),
      metadata: { securityEvent: true },
    });
    this.logger.warn(
      JSON.stringify({
        event: action,
        actorUserId: userId,
        targetId,
        securityEvent: true,
      }),
    );
  }

  private async safeAudit(data: Prisma.AuditLogUncheckedCreateInput) {
    try {
      await this.prisma.auditLog.create({ data });
    } catch (error) {
      this.logger.error(
        JSON.stringify({
          event: "auth.audit.failed",
          targetId: data.targetId,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
    }
  }

  private async verifyState(provider: OAuthProvider, state?: string) {
    if (!state) throw new BadRequestException("OAuth state is missing.");

    try {
      const payload = await this.jwtService.verifyAsync<OAuthState>(state);
      if (
        !["email-account-oauth", "email-account-reauth"].includes(
          payload.purpose ?? "",
        ) ||
        payload.provider !== provider ||
        !payload.loginSessionId
      ) {
        throw new Error("OAuth state does not match the request.");
      }
      const loginSession = await this.prisma.oAuthLoginSession.findFirst({
        where: {
          id: payload.loginSessionId,
          provider:
            provider === "google" ? EmailProvider.GOOGLE : EmailProvider.YAHOO,
          status: OAuthLoginStatus.PENDING,
          expiresAt: { gt: new Date() },
        },
        select: {
          id: true,
          pkceVerifierEncrypted: true,
          nonceHash: true,
          purpose: true,
          userId: true,
          appSessionId: true,
        },
      });
      if (!loginSession) throw new Error("OAuth login session is unavailable.");
      const expectedPurpose =
        loginSession.purpose === "REAUTH"
          ? "email-account-reauth"
          : "email-account-oauth";
      if (payload.purpose !== expectedPurpose) {
        throw new Error("OAuth purpose does not match the login session.");
      }
      return loginSession;
    } catch {
      this.logger.warn(
        JSON.stringify({
          event: "oauth.state_validation_failed",
          provider,
          securityEvent: true,
        }),
      );
      throw new UnauthorizedException("OAuth state is invalid or expired.");
    }
  }

  private async tokenResponse(
    user: { id: string; email: string },
    refreshToken: string,
    refreshExpiresAt: Date,
    sessionId: string,
    authenticatedAt: Date,
  ) {
    const payload: AccessTokenPayload = {
      sub: user.id,
      email: user.email,
      type: "access",
      sid: sessionId,
      auth_time: Math.floor(authenticatedAt.getTime() / 1_000),
    };
    return {
      status: "AUTHENTICATED" as const,
      accessToken: await this.jwtService.signAsync(payload),
      refreshToken,
      refreshExpiresAt: refreshExpiresAt.toISOString(),
      user,
    };
  }

  private async createAuthenticatedSession(
    user: { id: string; email: string },
    context: SessionContext,
  ) {
    const refreshToken = this.randomToken(48);
    const refreshExpiresAt = this.refreshExpiresAt();
    const authenticatedAt = new Date();
    const session = await this.prisma.appSession.create({
      data: {
        userId: user.id,
        familyId: this.randomToken(24),
        tokenHash: this.hashToken(refreshToken),
        expiresAt: refreshExpiresAt,
        authenticatedAt,
        ...this.sessionContextData(context),
      },
      select: { id: true },
    });
    return this.tokenResponse(
      user,
      refreshToken,
      refreshExpiresAt,
      session.id,
      authenticatedAt,
    );
  }

  private async reauthenticationResponse(
    user: { id: string; email: string },
    sessionId: string,
    authenticatedAt: Date,
  ) {
    const payload: AccessTokenPayload = {
      sub: user.id,
      email: user.email,
      type: "access",
      sid: sessionId,
      auth_time: Math.floor(authenticatedAt.getTime() / 1_000),
    };
    return {
      status: "REAUTHENTICATED" as const,
      accessToken: await this.jwtService.signAsync(payload),
      user,
    };
  }

  private refreshExpiresAt() {
    const days = Math.min(
      90,
      Math.max(1, this.config.get<number>("auth.refreshTokenDays", 90)),
    );
    return new Date(Date.now() + days * 24 * 60 * 60 * 1_000);
  }

  private randomToken(bytes: number) {
    return randomBytes(bytes).toString("base64url");
  }

  private hashToken(value: string) {
    return createHash("sha256").update(value).digest("hex");
  }

  private matchesHash(value: string, expectedHash: string) {
    const actual = Buffer.from(this.hashToken(value), "hex");
    const expected = Buffer.from(expectedHash, "hex");
    return (
      actual.length === expected.length && timingSafeEqual(actual, expected)
    );
  }

  private getGoogleConfig() {
    const clientId = this.config.get<string>("oauth.google.clientId");
    const clientSecret = this.config.get<string>("oauth.google.clientSecret");
    const callbackUrl = this.config.get<string>("oauth.google.callbackUrl");

    if (!clientId || !clientSecret || !callbackUrl) {
      throw new ServiceUnavailableException(
        "Google OAuth credentials are not configured in server/.env.",
      );
    }

    return { clientId, clientSecret, callbackUrl };
  }

  private getYahooConfig() {
    const clientId = this.config.get<string>("oauth.yahoo.clientId");
    const clientSecret = this.config.get<string>("oauth.yahoo.clientSecret");
    const callbackUrl = this.config.get<string>("oauth.yahoo.callbackUrl");
    if (!clientId || !clientSecret || !callbackUrl) {
      throw new ServiceUnavailableException(
        "Yahoo OAuth credentials are not configured in server/.env.",
      );
    }
    return { clientId, clientSecret, callbackUrl };
  }

  private async handleYahooOAuthCallback(
    code: string,
    loginSession: {
      id: string;
      pkceVerifierEncrypted: string;
      nonceHash: string;
      purpose: string;
      userId: string | null;
      appSessionId: string | null;
    },
  ) {
    try {
      const yahoo = this.getYahooConfig();
      const body = new URLSearchParams({
        code,
        client_id: yahoo.clientId,
        client_secret: yahoo.clientSecret,
        redirect_uri: yahoo.callbackUrl,
        grant_type: "authorization_code",
        code_verifier: this.tokenEncryption.decrypt(
          loginSession.pkceVerifierEncrypted,
          OAUTH_PKCE_CONTEXT,
        ),
      });
      let tokenResponse: Response;
      try {
        tokenResponse = await fetch(
          "https://api.login.yahoo.com/oauth2/get_token",
          {
            method: "POST",
            headers: { "Content-Type": "application/x-www-form-urlencoded" },
            body,
            signal: AbortSignal.timeout(15_000),
          },
        );
      } catch {
        throw new BadGatewayException("Could not reach Yahoo OAuth.");
      }
      if (!tokenResponse.ok) {
        const details = await tokenResponse.text();
        throw new BadGatewayException({
          message: "Yahoo rejected the authorization code.",
          providerStatus: tokenResponse.status,
          providerDetails: details.slice(0, 500),
        });
      }
      const tokens = (await tokenResponse.json()) as YahooTokenResponse;
      if (!tokens.access_token) {
        throw new BadGatewayException(
          "Yahoo did not return an OAuth access token.",
        );
      }
      let identityResponse: Response;
      try {
        identityResponse = await fetch(
          "https://api.login.yahoo.com/openid/v1/userinfo",
          {
            headers: { Authorization: `Bearer ${tokens.access_token}` },
            signal: AbortSignal.timeout(15_000),
          },
        );
      } catch {
        throw new BadGatewayException(
          "Could not validate the Yahoo account identity.",
        );
      }
      if (!identityResponse.ok) {
        throw new UnauthorizedException("Yahoo identity validation failed.");
      }
      const identity = (await identityResponse.json()) as YahooUserInfo;
      if (
        !identity.sub ||
        !identity.email ||
        identity.email_verified !== true
      ) {
        throw new UnauthorizedException(
          "Yahoo did not return a verified account identity.",
        );
      }
      if (loginSession.purpose === "REAUTH") {
        throw new BadRequestException(
          "Yahoo cannot be used to verify a Google-authenticated session.",
        );
      }
      if (!tokens.refresh_token) {
        throw new BadGatewayException(
          "Yahoo did not return offline access. Remove SenderWho from Yahoo and connect again.",
        );
      }

      const normalizedEmail = identity.email.trim().toLowerCase();
      let user = await this.prisma.user.findFirst({
        where: {
          deletedAt: null,
          OR: [{ yahooSubject: identity.sub }, { email: normalizedEmail }],
        },
      });
      if (!user) {
        user = await this.prisma.user.create({
          data: {
            email: normalizedEmail,
            yahooSubject: identity.sub,
            displayName: identity.name,
            avatarUrl: identity.picture,
          },
        });
      } else {
        if (user.yahooSubject && user.yahooSubject !== identity.sub) {
          throw new UnauthorizedException(
            "This email address is already linked to a different Yahoo identity.",
          );
        }
        user = await this.prisma.user.update({
          where: { id: user.id },
          data: {
            yahooSubject: identity.sub,
            email: normalizedEmail,
            displayName: user.displayName ?? identity.name,
            avatarUrl: user.avatarUrl ?? identity.picture,
          },
        });
      }

      const tokenContext = yahooProviderTokenContext(identity.sub);
      const account = await this.prisma.emailAccount.upsert({
        where: {
          provider_providerAccountId: {
            provider: EmailProvider.YAHOO,
            providerAccountId: identity.sub,
          },
        },
        create: {
          userId: user.id,
          provider: EmailProvider.YAHOO,
          providerAccountId: identity.sub,
          emailAddress: normalizedEmail,
          displayName: identity.name,
          accessTokenEncrypted: this.tokenEncryption.encrypt(
            tokens.access_token,
            tokenContext,
          ),
          refreshTokenEncrypted: this.tokenEncryption.encrypt(
            tokens.refresh_token,
            tokenContext,
          ),
          tokenExpiresAt: tokens.expires_in
            ? new Date(Date.now() + tokens.expires_in * 1_000)
            : null,
          scopes: (tokens.scope ?? YAHOO_SCOPES.join(" "))
            .split(/[ ,]+/)
            .filter(Boolean),
          syncStatus: SyncStatus.FAILED,
          lastSyncError:
            "Yahoo login succeeded, but Yahoo mailbox scanning is not available until Yahoo mail access is approved and configured.",
        },
        update: {
          userId: user.id,
          emailAddress: normalizedEmail,
          displayName: identity.name,
          accessTokenEncrypted: this.tokenEncryption.encrypt(
            tokens.access_token,
            tokenContext,
          ),
          refreshTokenEncrypted: this.tokenEncryption.encrypt(
            tokens.refresh_token,
            tokenContext,
          ),
          tokenExpiresAt: tokens.expires_in
            ? new Date(Date.now() + tokens.expires_in * 1_000)
            : null,
          scopes: (tokens.scope ?? YAHOO_SCOPES.join(" "))
            .split(/[ ,]+/)
            .filter(Boolean),
          syncStatus: SyncStatus.FAILED,
          lastSyncError:
            "Yahoo login succeeded, but Yahoo mailbox scanning is not available until Yahoo mail access is approved and configured.",
        },
      });
      await this.prisma.oAuthLoginSession.update({
        where: { id: loginSession.id },
        data: { userId: user.id, status: OAuthLoginStatus.COMPLETED },
      });
      await this.safeAudit({
        userId: user.id,
        action: "email_account.connected",
        targetType: "EmailAccount",
        targetId: account.id,
        metadata: { provider: EmailProvider.YAHOO },
      });
      return {
        success: true,
        provider: "yahoo" as const,
        emailAddress: normalizedEmail,
        emailAccountId: account.id,
        persisted: true,
        reauthenticated: false,
      };
    } catch (error) {
      await this.prisma.oAuthLoginSession.updateMany({
        where: { id: loginSession.id, status: OAuthLoginStatus.PENDING },
        data: {
          status: OAuthLoginStatus.FAILED,
          error: this.safeErrorMessage(error),
        },
      });
      throw error;
    }
  }

  private async exchangeGoogleCode(
    code: string,
    google: { clientId: string; clientSecret: string; callbackUrl: string },
    codeVerifier: string,
  ): Promise<GoogleTokenResponse> {
    const body = new URLSearchParams({
      code,
      client_id: google.clientId,
      client_secret: google.clientSecret,
      redirect_uri: google.callbackUrl,
      grant_type: "authorization_code",
      code_verifier: codeVerifier,
    });

    let response: Response;
    try {
      response = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body,
        signal: AbortSignal.timeout(15_000),
      });
    } catch {
      throw new BadGatewayException("Could not reach Google OAuth.");
    }

    if (!response.ok) {
      const details = await response.text();
      throw new BadGatewayException({
        message: "Google rejected the authorization code.",
        providerStatus: response.status,
        providerDetails: details.slice(0, 500),
      });
    }

    return (await response.json()) as GoogleTokenResponse;
  }

  private async validateGoogleIdToken(
    idToken: string,
    expectedAudience: string,
    expectedNonceHash: string,
  ): Promise<GoogleIdTokenClaims> {
    let response: Response;
    try {
      response = await fetch(
        `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
        {
          signal: AbortSignal.timeout(15_000),
        },
      );
    } catch {
      throw new BadGatewayException(
        "Could not validate the Google account identity.",
      );
    }

    if (!response.ok) {
      throw new UnauthorizedException("Google identity validation failed.");
    }
    const claims = (await response.json()) as GoogleIdTokenClaims;
    const now = Math.floor(Date.now() / 1_000);
    const expiresAt = Number(claims.exp);
    const issuedAt = Number(claims.iat);
    const verifiedEmail =
      claims.email_verified === true || claims.email_verified === "true";
    const issuerAllowed =
      claims.iss === "accounts.google.com" ||
      claims.iss === "https://accounts.google.com";
    if (
      claims.aud !== expectedAudience ||
      !issuerAllowed ||
      !claims.sub ||
      !claims.email ||
      !verifiedEmail ||
      !Number.isFinite(expiresAt) ||
      expiresAt < now - OIDC_CLOCK_SKEW_SECONDS ||
      !Number.isFinite(issuedAt) ||
      issuedAt > now + OIDC_CLOCK_SKEW_SECONDS ||
      issuedAt < now - 3_600 - OIDC_CLOCK_SKEW_SECONDS ||
      !claims.nonce ||
      this.hashToken(claims.nonce) !== expectedNonceHash
    ) {
      throw new UnauthorizedException(
        "Google identity claims are invalid or expired.",
      );
    }
    return claims;
  }

  private async resolveGoogleUser(
    googleSubject: string,
    emailAddress: string,
    existingUserId?: string,
  ) {
    const normalizedEmail = emailAddress.trim().toLowerCase();
    const user = existingUserId
      ? await this.prisma.user.findFirst({
          where: { id: existingUserId, deletedAt: null },
        })
      : await this.prisma.user.findFirst({
          where: {
            deletedAt: null,
            OR: [{ googleSubject }, { email: normalizedEmail }],
          },
        });
    if (!user) {
      return this.prisma.user.create({
        data: { email: normalizedEmail, googleSubject },
      });
    }
    if (user.googleSubject && user.googleSubject !== googleSubject) {
      throw new UnauthorizedException(
        "This email address is already linked to a different Google identity.",
      );
    }
    const emailOwner = await this.prisma.user.findUnique({
      where: { email: normalizedEmail },
      select: { id: true },
    });
    if (emailOwner && emailOwner.id !== user.id) {
      throw new UnauthorizedException(
        "The Google identity email conflicts with another SenderWho account.",
      );
    }
    return this.prisma.user.update({
      where: { id: user.id },
      data: { googleSubject, email: normalizedEmail },
    });
  }

  private safeErrorMessage(error: unknown) {
    return error instanceof Error
      ? error.message.slice(0, 1_000)
      : "Unknown error";
  }
}
