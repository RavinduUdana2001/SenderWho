import { ConfigService } from "@nestjs/config";
import { randomBytes } from "node:crypto";
import { TokenEncryptionService } from "./token-encryption.service";

describe("TokenEncryptionService", () => {
  it("encrypts and decrypts a provider token", () => {
    const config = new ConfigService({
      auth: { tokenEncryptionKey: randomBytes(32).toString("base64") },
    });
    const service = new TokenEncryptionService(config);

    const encrypted = service.encrypt("refresh-token-value");

    expect(encrypted).not.toContain("refresh-token-value");
    expect(service.decrypt(encrypted)).toBe("refresh-token-value");
  });

  it("binds ciphertext to its record context and identifies rotation", () => {
    const first = randomBytes(32).toString("base64");
    const second = randomBytes(32).toString("base64");
    const keys = `key-old:${first},key-current:${second}`;
    const oldService = new TokenEncryptionService(
      new ConfigService({
        auth: {
          tokenEncryptionKeys: keys,
          tokenEncryptionActiveKeyId: "key-old",
        },
      }),
    );
    const encrypted = oldService.encrypt("provider-token", "account:one");
    const currentService = new TokenEncryptionService(
      new ConfigService({
        auth: {
          tokenEncryptionKeys: keys,
          tokenEncryptionActiveKeyId: "key-current",
        },
      }),
    );

    expect(currentService.decrypt(encrypted, "account:one")).toBe(
      "provider-token",
    );
    expect(currentService.needsRotation(encrypted)).toBe(true);
    expect(() => currentService.decrypt(encrypted, "account:two")).toThrow();
  });
});

describe("safe cryptographic failures", () => {
  it("returns the same safe external error for corruption, context, and missing keys", () => {
    const service = new TokenEncryptionService(
      new ConfigService({
        auth: { tokenEncryptionKey: randomBytes(32).toString("base64") },
      }),
    );
    const payload = service.encrypt("private-plaintext");
    const mutate = (index: number) => {
      const parts = payload.split(".");
      const bytes = Buffer.from(parts[index], "base64url");
      bytes[0] ^= 1;
      parts[index] = bytes.toString("base64url");
      return parts.join(".");
    };
    const missing = new TokenEncryptionService(new ConfigService({ auth: {} }));
    for (const operation of [
      () => service.decrypt("invalid"),
      () => service.decrypt(mutate(3)),
      () => service.decrypt(mutate(4)),
      () => service.decrypt(payload, "wrong-context"),
      () => missing.decrypt(payload),
      () => missing.encrypt("private-plaintext"),
      () => service.decrypt(payload.replace(".legacy.", ".missing.")),
    ]) {
      try {
        operation();
        throw new Error("Expected crypto rejection");
      } catch (error) {
        expect((error as { getResponse: () => unknown }).getResponse()).toEqual(
          {
            statusCode: 503,
            error: "Service Unavailable",
            message: "Secure credential processing failed.",
          },
        );
      }
    }
  });
});
