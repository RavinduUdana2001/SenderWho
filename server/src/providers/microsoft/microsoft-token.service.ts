import {
  BadGatewayException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { EmailProvider, SyncStatus } from "@prisma/client";
import {
  microsoftProviderTokenContext,
  TokenEncryptionService,
} from "../../common/security/token-encryption.service";
import { PrismaService } from "../../database/prisma.service";

interface MicrosoftRefreshResponse {
  access_token?: string;
  expires_in?: number;
  refresh_token?: string;
  scope?: string;
  error?: string;
  error_description?: string;
}

@Injectable()
export class MicrosoftTokenService {
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
    if (!account || account.provider !== EmailProvider.MICROSOFT) {
      throw new NotFoundException(
        "Connected Microsoft Outlook account was not found.",
      );
    }
    if (account.syncStatus === SyncStatus.DISCONNECTED) {
      throw new UnauthorizedException(
        "The Microsoft Outlook account must be reconnected.",
      );
    }

    const context = microsoftProviderTokenContext(account.providerAccountId);
    const usableUntil = Date.now() + 2 * 60 * 1_000;
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
        "Microsoft authorization is unavailable. Reconnect Outlook.",
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
    const clientId = this.config.get<string>("oauth.microsoft.clientId");
    const clientSecret = this.config.get<string>(
      "oauth.microsoft.clientSecret",
    );
    if (!clientId || !clientSecret) {
      throw new BadGatewayException("Microsoft OAuth is not configured.");
    }
    const context = microsoftProviderTokenContext(providerAccountId);
    const refreshToken = this.encryption.decrypt(
      encryptedRefreshToken,
      context,
    );
    const body = new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
      scope: "openid profile email offline_access User.Read Mail.ReadWrite",
    });
    let response: Response;
    try {
      response = await fetch(
        "https://login.microsoftonline.com/common/oauth2/v2.0/token",
        {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body,
          signal: AbortSignal.timeout(15_000),
        },
      );
    } catch {
      throw new BadGatewayException(
        "Could not refresh Microsoft Outlook access.",
      );
    }
    const tokens = (await this.readResponse(
      response,
    )) as MicrosoftRefreshResponse;
    if (!response.ok) {
      if (
        tokens.error === "invalid_grant" ||
        tokens.error === "interaction_required"
      ) {
        await this.prisma.emailAccount.update({
          where: { id: emailAccountId },
          data: {
            syncStatus: SyncStatus.DISCONNECTED,
            lastSyncError:
              "Microsoft Outlook access expired or was revoked. Reconnect Outlook to continue scanning.",
          },
        });
        throw new UnauthorizedException(
          "Microsoft Outlook access was revoked. Reconnect Outlook.",
        );
      }
      if (tokens.error === "invalid_client") {
        throw new BadGatewayException(
          "The SenderWho Microsoft OAuth credentials are invalid.",
        );
      }
      throw new BadGatewayException("Microsoft token refresh failed.");
    }
    if (!tokens.access_token) {
      throw new BadGatewayException(
        "Microsoft did not return a refreshed access token.",
      );
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
          Date.now() + Math.max(60, tokens.expires_in ?? 3_600) * 1_000,
        ),
        ...(tokens.scope
          ? { scopes: tokens.scope.split(/\s+/).filter(Boolean) }
          : {}),
      },
    });
    return tokens.access_token;
  }

  private async readResponse(response: Response) {
    try {
      const body = (await response.json()) as MicrosoftRefreshResponse;
      return typeof body === "object" && body !== null ? body : {};
    } catch {
      return {};
    }
  }
}
