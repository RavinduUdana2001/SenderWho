import { Injectable, ServiceUnavailableException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";

const ALGORITHM = "aes-256-gcm";
const IV_LENGTH = 12;
const KEY_LENGTH = 32;
const LEGACY_VERSION = "v1";
const VERSION = "v2";
const DEFAULT_CONTEXT = "senderwho-provider-token";

export const OAUTH_PKCE_CONTEXT = "senderwho-oauth-pkce";
export const googleProviderTokenContext = (providerAccountId: string) =>
  `senderwho-google-token:${providerAccountId}`;
export const yahooProviderTokenContext = (providerAccountId: string) =>
  `senderwho-yahoo-token:${providerAccountId}`;

@Injectable()
export class TokenEncryptionService {
  constructor(private readonly config: ConfigService) {}

  encrypt(value: string, context = DEFAULT_CONTEXT): string {
    const { id: keyId, key } = this.getActiveKey();
    const iv = randomBytes(IV_LENGTH);
    const cipher = createCipheriv(ALGORITHM, key, iv);
    cipher.setAAD(Buffer.from(context, "utf8"));
    const encrypted = Buffer.concat([
      cipher.update(value, "utf8"),
      cipher.final(),
    ]);
    const tag = cipher.getAuthTag();

    return [
      VERSION,
      keyId,
      iv.toString("base64url"),
      tag.toString("base64url"),
      encrypted.toString("base64url"),
    ].join(".");
  }

  decrypt(payload: string, context = DEFAULT_CONTEXT): string {
    const parts = payload.split(".");
    if (parts[0] === LEGACY_VERSION) return this.decryptLegacy(parts);
    const [version, keyId, ivValue, tagValue, encryptedValue] = parts;
    if (
      version !== VERSION ||
      !keyId ||
      !ivValue ||
      !tagValue ||
      !encryptedValue
    ) {
      throw new Error("Invalid encrypted token format.");
    }

    const key = this.getKeyRing().get(keyId);
    if (!key) {
      throw new ServiceUnavailableException(
        `Token encryption key '${keyId}' is unavailable.`,
      );
    }
    const decipher = createDecipheriv(
      ALGORITHM,
      key,
      Buffer.from(ivValue, "base64url"),
    );
    decipher.setAAD(Buffer.from(context, "utf8"));
    decipher.setAuthTag(Buffer.from(tagValue, "base64url"));
    return Buffer.concat([
      decipher.update(Buffer.from(encryptedValue, "base64url")),
      decipher.final(),
    ]).toString("utf8");
  }

  needsRotation(payload: string): boolean {
    const [version, keyId] = payload.split(".");
    return version !== VERSION || keyId !== this.getActiveKey().id;
  }

  private decryptLegacy(parts: string[]): string {
    const [version, ivValue, tagValue, encryptedValue] = parts;
    if (
      version !== LEGACY_VERSION ||
      !ivValue ||
      !tagValue ||
      !encryptedValue
    ) {
      throw new Error("Invalid encrypted token format.");
    }
    const decipher = createDecipheriv(
      ALGORITHM,
      this.getLegacyKey(),
      Buffer.from(ivValue, "base64url"),
    );
    decipher.setAuthTag(Buffer.from(tagValue, "base64url"));
    return Buffer.concat([
      decipher.update(Buffer.from(encryptedValue, "base64url")),
      decipher.final(),
    ]).toString("utf8");
  }

  private getActiveKey() {
    const keyRing = this.getKeyRing();
    const configuredId = this.config.get<string>(
      "auth.tokenEncryptionActiveKeyId",
    );
    const id = configuredId || "legacy";
    const key = keyRing.get(id);
    if (!key) {
      throw new ServiceUnavailableException(
        "The active token encryption key is unavailable.",
      );
    }
    return { id, key };
  }

  private getKeyRing(): Map<string, Buffer> {
    const keyRing = new Map<string, Buffer>();
    const configured = this.config.get<string>("auth.tokenEncryptionKeys");
    for (const entry of configured?.split(",") ?? []) {
      const separator = entry.indexOf(":");
      if (separator <= 0) continue;
      const id = entry.slice(0, separator).trim();
      const encoded = entry.slice(separator + 1).trim();
      const key = Buffer.from(encoded, "base64");
      if (/^[A-Za-z0-9_-]{1,40}$/.test(id) && key.length === KEY_LENGTH) {
        keyRing.set(id, key);
      }
    }
    const legacy = this.config.get<string>("auth.tokenEncryptionKey");
    if (legacy) {
      const key = Buffer.from(legacy, "base64");
      if (key.length === KEY_LENGTH) keyRing.set("legacy", key);
    }
    if (keyRing.size === 0) {
      throw new ServiceUnavailableException(
        "No valid token encryption keys are configured.",
      );
    }
    return keyRing;
  }

  private getLegacyKey(): Buffer {
    const encodedKey = this.config.get<string>("auth.tokenEncryptionKey");
    if (!encodedKey) {
      throw new ServiceUnavailableException(
        "TOKEN_ENCRYPTION_KEY is not configured for legacy token decryption.",
      );
    }
    const key = Buffer.from(encodedKey, "base64");
    if (key.length !== KEY_LENGTH) {
      throw new ServiceUnavailableException(
        "TOKEN_ENCRYPTION_KEY must be a Base64-encoded 32-byte key.",
      );
    }
    return key;
  }
}
