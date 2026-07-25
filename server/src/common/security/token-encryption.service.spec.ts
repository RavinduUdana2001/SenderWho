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
