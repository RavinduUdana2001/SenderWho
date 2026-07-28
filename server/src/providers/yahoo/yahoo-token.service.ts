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
  yahooProviderTokenContext,
} from "../../common/security/token-encryption.service";
import { PrismaService } from "../../database/prisma.service";

interface YahooRefreshResponse {
  access_token?: string;
  expires_in?: number;
  refresh_token?: string;
  scope?: string;
}

interface YahooOAuthErrorResponse {
  error?: string;
  error_description?: string;
}

@Injectable()
export class YahooTokenService {
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
    if (!account || account.provider !== EmailProvider.YAHOO) {
      throw new NotFoundException("Connected Yahoo account was not found.");
    }
    if (account.syncStatus === SyncStatus.DISCONNECTED) {
      throw new UnauthorizedException("The Yahoo account must be reconnected.");
    }

    const usableUntil = Date.now() + 2 * 60 * 1_000;
    const context = yahooProviderTokenContext(account.providerAccountId);
    if (
      !forceRefresh &&
      account.accessTokenEncrypted &&
      account.tokenExpiresAt &&
      account.tokenExpiresAt.getTime() > usableUntil
    ) {
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
        "Yahoo authorization is unavailable. Reconnect Yahoo Mail.",
      );
    }
    const activeRefresh = this.refreshes.get(emailAccountId);
    if (activeRefresh) return activeRefresh;

    const refresh = this.refreshAccessToken(
      emailAccountId,
      account.providerAccountId,
      account.refreshTokenEncrypted,
    ).finally(() => this.refreshes.delete(emailAccountId));
    this.refreshes.set(emailAccountId, refresh);
    return refresh;
  }

  private async refreshAccessToken(
    emailAccountId: string,
    providerAccountId: string,
    encryptedRefreshToken: string,
  ) {
    const clientId = this.config.get<string>("oauth.yahoo.clientId");
    const clientSecret = this.config.get<string>("oauth.yahoo.clientSecret");
    const callbackUrl = this.config.get<string>("oauth.yahoo.callbackUrl");
    if (!clientId || !clientSecret || !callbackUrl) {
      throw new BadGatewayException("Yahoo OAuth is not configured.");
    }
    const context = yahooProviderTokenContext(providerAccountId);
    const refreshToken = this.encryption.decrypt(
      encryptedRefreshToken,
      context,
    );
    const body = new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      redirect_uri: callbackUrl,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    });

    let response: Response;
    try {
      response = await fetch("https://api.login.yahoo.com/oauth2/get_token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body,
        signal: AbortSignal.timeout(15_000),
      });
    } catch {
      throw new BadGatewayException("Could not refresh Yahoo access.");
    }
    if (!response.ok) {
      const details = await this.readOAuthError(response);
      if (["invalid_grant", "invalid_request"].includes(details.error ?? "")) {
        await this.prisma.emailAccount.update({
          where: { id: emailAccountId },
          data: {
            syncStatus: SyncStatus.DISCONNECTED,
            lastSyncError:
              "Yahoo access expired or was revoked. Reconnect Yahoo Mail to continue scanning.",
          },
        });
        throw new UnauthorizedException(
          "Yahoo access was revoked. Reconnect Yahoo Mail.",
        );
      }
      if (details.error === "invalid_client") {
        throw new BadGatewayException(
          "The SenderWho Yahoo OAuth credentials are invalid.",
        );
      }
      throw new BadGatewayException({
        message: "Yahoo token refresh failed.",
        providerStatus: response.status,
        providerError: details.error ?? "unknown_error",
      });
    }

    const tokens = (await response.json()) as YahooRefreshResponse;
    if (!tokens.access_token) {
      throw new BadGatewayException("Yahoo did not return an access token.");
    }
    await this.prisma.emailAccount.update({
      where: { id: emailAccountId },
      data: {
        accessTokenEncrypted: this.encryption.encrypt(
          tokens.access_token,
          context,
        ),
        ...(tokens.refresh_token
          ? {
              refreshTokenEncrypted: this.encryption.encrypt(
                tokens.refresh_token,
                context,
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
        ...(tokens.scope
          ? {
              scopes: tokens.scope.split(/[ ,]+/).filter(Boolean),
            }
          : {}),
      },
    });
    return tokens.access_token;
  }

  private async readOAuthError(response: Response) {
    try {
      const body = (await response.json()) as YahooOAuthErrorResponse;
      return typeof body === "object" && body !== null ? body : {};
    } catch {
      return {};
    }
  }
}
