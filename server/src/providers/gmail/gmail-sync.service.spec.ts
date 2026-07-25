import { RiskLevel, SenderCategory } from "@prisma/client";
import {
  aggregateSenderClassification,
  CURRENT_GMAIL_METADATA_VERSION,
  extractSecureUnsubscribeUrl,
  isImportantOrStarred,
} from "./gmail-sync.service";

describe("Gmail sender classification", () => {
  it("forces one reconciliation for the identity-header metadata revision", () => {
    expect(CURRENT_GMAIL_METADATA_VERSION).toBe(3);
  });

  it("keeps the maximum risk independent of message completion order", () => {
    const firstOrder = aggregateSenderClassification(
      [SenderCategory.PEOPLE, SenderCategory.SPAM],
      SenderCategory.PEOPLE,
    );
    const reversedOrder = aggregateSenderClassification(
      [SenderCategory.SPAM, SenderCategory.PEOPLE],
      SenderCategory.PEOPLE,
    );

    expect(firstOrder).toEqual(reversedOrder);
    expect(firstOrder).toEqual({
      category: SenderCategory.PEOPLE,
      riskLevel: RiskLevel.HIGH,
      trustScore: 50,
      identityRiskScore: 0,
      identityRiskLevel: "LOW",
      identityStatus: "UNVERIFIED",
    });
  });

  it("uses the latest message category while retaining aggregate risk", () => {
    expect(
      aggregateSenderClassification(
        [SenderCategory.PROMOTIONS, SenderCategory.UNKNOWN],
        SenderCategory.PROMOTIONS,
      ),
    ).toEqual({
      category: SenderCategory.PROMOTIONS,
      riskLevel: RiskLevel.LOW,
      trustScore: 70,
      identityRiskScore: 0,
      identityRiskLevel: "LOW",
      identityStatus: "UNVERIFIED",
    });
  });

  it.each([
    [["CATEGORY_PROMOTIONS", "IMPORTANT"], true],
    [["STARRED"], true],
    [["CATEGORY_PROMOTIONS"], false],
  ] as const)(
    "materializes Gmail protection from labels",
    (labels, expected) => {
      expect(isImportantOrStarred([...labels])).toBe(expected);
    },
  );

  it("selects a secure one-click URL from a mixed unsubscribe header", () => {
    expect(
      extractSecureUnsubscribeUrl(
        "<mailto:leave@example.test>, <HTTPS://example.test/unsubscribe>",
      ),
    ).toBe("https://example.test/unsubscribe");
    expect(
      extractSecureUnsubscribeUrl("<https://user:secret@example.test/leave>"),
    ).toBeUndefined();
    expect(
      extractSecureUnsubscribeUrl("<http://example.test/leave>"),
    ).toBeUndefined();
  });
});
