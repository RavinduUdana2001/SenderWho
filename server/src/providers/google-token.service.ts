import {
  BadGatewayException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { EmailProvider, SyncStatus } from "@prisma/client";
import {
  TokenEncryptionService,
  googleProviderTokenContext,
} from "../common/security/token-encryption.service";
import { PrismaService } from "../database/prisma.service";

interface GoogleRefreshResponse {
  access_token?: string;
  expires_in?: number;
  refresh_token?: string;
  scope?: string;
}

interface GoogleOAuthErrorResponse {
  error?: string;
  error_description?: string;
}

@Injectable()
export class GoogleTokenService {
  private readonly refreshes = new Map<string, Promise<string>>();

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly encryption: TokenEncryptionService,
  ) {}

  async getAccessToken(
    emailAccountId: string,
    forceRefresh = false,
  ): Promise<string> {
    const account = await this.prisma.emailAccount.findUnique({
      where: { id: emailAccountId },
      select: {
        provider: true,
        providerAccountId: true,
        syncStatus: true,
        accessTokenEncrypted: true,
        refreshTokenEncrypted: true,
        tokenExpiresAt: true,
      },
    });

    if (!account || account.provider !== EmailProvider.GOOGLE) {
      throw new NotFoundException("Connected Google account was not found.");
    }
    if (account.syncStatus === SyncStatus.DISCONNECTED) {
      throw new UnauthorizedException(
        "The Google account must be reconnected.",
      );
    }

    const usableUntil = Date.now() + 2 * 60 * 1_000;
    if (
      !forceRefresh &&
      account.accessTokenEncrypted &&
      account.tokenExpiresAt &&
      account.tokenExpiresAt.getTime() > usableUntil
    ) {
      const context = googleProviderTokenContext(account.providerAccountId);
      const accessToken = this.encryption.decrypt(
        account.accessTokenEncrypted,
        context,
      );
      if (this.encryption.needsRotation(account.accessTokenEncrypted)) {
        await this.prisma.emailAccount.update({
          where: { id: emailAccountId },
          data: {
            accessTokenEncrypted: this.encryption.encrypt(accessToken, context),
          },
        });
      }
      return accessToken;
    }

    if (!account.refreshTokenEncrypted) {
      throw new UnauthorizedException(
        "The Google account has no refresh token and must be reconnected.",
      );
    }

    const activeRefresh = this.refreshes.get(emailAccountId);
    if (activeRefresh) return activeRefresh;

    const refresh = this.refreshAccessToken(
      emailAccountId,
      account.refreshTokenEncrypted,
      account.providerAccountId,
    ).finally(() => this.refreshes.delete(emailAccountId));
    this.refreshes.set(emailAccountId, refresh);
    return refresh;
  }

  private async refreshAccessToken(
    emailAccountId: string,
    encryptedRefreshToken: string,
    providerAccountId: string,
  ): Promise<string> {
    const clientId = this.config.get<string>("oauth.google.clientId");
    const clientSecret = this.config.get<string>("oauth.google.clientSecret");
    if (!clientId || !clientSecret) {
      throw new BadGatewayException("Google OAuth is not configured.");
    }

    const context = googleProviderTokenContext(providerAccountId);
    const refreshToken = this.encryption.decrypt(
      encryptedRefreshToken,
      context,
    );
    const body = new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
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
      throw new BadGatewayException("Could not refresh Google access.");
    }

    if (!response.ok) {
      const details = await this.readOAuthError(response);
      if (details.error === "invalid_grant") {
        await this.prisma.emailAccount.update({
          where: { id: emailAccountId },
          data: {
            syncStatus: SyncStatus.DISCONNECTED,
            lastSyncError:
              "Google access expired or was revoked. Reconnect Gmail to continue scanning.",
          },
        });
        throw new UnauthorizedException(
          "Google access was revoked. Reconnect the account.",
        );
      }

      if (details.error === "disabled_client") {
        throw new BadGatewayException(
          "The SenderWho Google OAuth client is disabled. Enable it in Google Cloud Console, then reconnect Gmail.",
        );
      }

      if (details.error === "invalid_client") {
        throw new BadGatewayException(
          "The SenderWho Google OAuth credentials are invalid. Update the server configuration, then reconnect Gmail.",
        );
      }

      throw new BadGatewayException({
        message: "Google token refresh failed.",
        providerStatus: response.status,
        providerError: details.error ?? "unknown_error",
      });
    }

    const tokens = (await response.json()) as GoogleRefreshResponse;
    if (!tokens.access_token) {
      throw new BadGatewayException("Google did not return an access token.");
    }

    await this.prisma.emailAccount.update({
      where: { id: emailAccountId },
      data: {
        accessTokenEncrypted: this.encryption.encrypt(
          tokens.access_token,
          googleProviderTokenContext(providerAccountId),
        ),
        ...(tokens.refresh_token
          ? {
              refreshTokenEncrypted: this.encryption.encrypt(
                tokens.refresh_token,
                googleProviderTokenContext(providerAccountId),
              ),
            }
          : this.encryption.needsRotation(encryptedRefreshToken)
            ? {
                refreshTokenEncrypted: this.encryption.encrypt(
                  refreshToken,
                  context,
                ),
              }
            : {}),
        tokenExpiresAt: new Date(
          Date.now() + (tokens.expires_in ?? 3_600) * 1_000,
        ),
      },
    });

    return tokens.access_token;
  }

  private async readOAuthError(
    response: Response,
  ): Promise<GoogleOAuthErrorResponse> {
    try {
      const body = (await response.json()) as GoogleOAuthErrorResponse;
      return typeof body === "object" && body !== null ? body : {};
    } catch {
      return {};
    }
  }
}
