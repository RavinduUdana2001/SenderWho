import { IdentityRiskLevel, IdentityStatus } from "@prisma/client";
import { SenderIdentityRiskService } from "./sender-identity-risk.service";

describe("SenderIdentityRiskService", () => {
  const service = new SenderIdentityRiskService();
  const assess = (input: {
    displayName?: string;
    fromEmail: string;
    labels?: string[];
    headers?: Record<string, string | string[]>;
  }) => service.assess({ labels: [], headers: {}, ...input });

  it("verifies an official Google domain with aligned DKIM", () => {
    const result = assess({
      displayName: "Google",
      fromEmail: "no-reply@accounts.google.com",
      headers: {
        "authentication-results":
          "mx.google.com; dkim=pass header.d=google.com; dmarc=pass header.from=google.com",
      },
    });
    expect(result.status).toBe(IdentityStatus.VERIFIED);
    expect(result.score).toBe(0);
  });

  it("verifies a non-brand sender when Gmail reports aligned DMARC", () => {
    const result = assess({
      displayName: "Example Billing",
      fromEmail: "billing@example.com",
      headers: {
        "authentication-results":
          "mx.google.com; dkim=pass header.d=example.com; dmarc=pass header.from=example.com",
      },
    });
    expect(result.status).toBe(IdentityStatus.VERIFIED);
    expect(result.score).toBe(0);
  });

  it.each(["alerts@goog1e.com", "alerts@google.example.com"])(
    "detects Google impersonation from %s",
    (fromEmail) => {
      const result = assess({ displayName: "Google Security", fromEmail });
      expect(result.evidence.map((item) => item.code)).toContain(
        "BRAND_DOMAIN_MISMATCH",
      );
      expect(result.score).toBeGreaterThanOrEqual(35);
    },
  );

  it("raises possible impersonation when a brand mismatch is reinforced by Reply-To", () => {
    const result = assess({
      displayName: "Google",
      fromEmail: "security@example.net",
      headers: { "reply-to": "collect@attacker.example" },
    });
    expect(result.level).toBe(IdentityRiskLevel.POSSIBLE_IMPERSONATION);
    expect(result.evidence.map((item) => item.code)).toContain(
      "REPLY_TO_MISMATCH",
    );
  });

  it("does not flag a display name alone when no known brand is claimed", () => {
    const result = assess({
      displayName: "Friendly Team",
      fromEmail: "hello@example.com",
    });
    expect(result.score).toBe(0);
    expect(result.status).toBe(IdentityStatus.UNVERIFIED);
  });

  it("does not count forwarded authentication failures when ARC passes", () => {
    const result = assess({
      fromEmail: "person@example.com",
      headers: {
        "authentication-results":
          "mx.google.com; spf=fail; dkim=fail; dmarc=fail",
        "arc-authentication-results": "i=1; dkim=pass header.d=example.com",
      },
    });
    expect(result.evidence).toEqual([]);
  });

  it("does not count expected mailing-list authentication rewrites", () => {
    const result = assess({
      fromEmail: "person@example.com",
      headers: {
        "list-id": "Example Community <community.example.org>",
        "authentication-results":
          "mx.google.com; spf=fail; dkim=fail; dmarc=fail",
        "reply-to": "community@example.org",
      },
    });
    expect(result.evidence).toEqual([]);
  });

  it("treats an internationalized domain claiming a known brand as lookalike evidence", () => {
    const result = assess({
      displayName: "Google",
      fromEmail: "security@göögle.example",
    });
    expect(result.evidence.map((item) => item.code)).toContain(
      "LOOKALIKE_DOMAIN",
    );
  });

  it("handles malformed headers without throwing", () => {
    expect(() =>
      assess({
        fromEmail: "invalid",
        headers: { "authentication-results": ";;;" },
      }),
    ).not.toThrow();
  });
});
