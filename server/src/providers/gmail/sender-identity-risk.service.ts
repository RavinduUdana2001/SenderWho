import { domainToASCII } from "node:url";
import { Injectable } from "@nestjs/common";
import { IdentityRiskLevel, IdentityStatus } from "@prisma/client";

export type IdentityEvidenceCode =
  | "BRAND_DOMAIN_MISMATCH"
  | "LOOKALIKE_DOMAIN"
  | "SPF_FAILED"
  | "DKIM_FAILED"
  | "DMARC_FAILED"
  | "AUTH_DOMAIN_MISMATCH"
  | "REPLY_TO_MISMATCH"
  | "RETURN_PATH_MISMATCH"
  | "GMAIL_SPAM_CLASSIFICATION";

export interface IdentityEvidence {
  code: IdentityEvidenceCode;
  weight: number;
  detail: string;
}

export interface IdentityAssessment {
  score: number;
  level: IdentityRiskLevel;
  status: IdentityStatus;
  claimedBrand?: string;
  authenticatedDomain?: string;
  replyToEmail?: string;
  evidence: IdentityEvidence[];
}

interface BrandDefinition {
  name: string;
  aliases: string[];
  domains: string[];
}

const BRANDS: BrandDefinition[] = [
  {
    name: "Google",
    aliases: ["google", "gmail"],
    domains: ["google.com", "gmail.com"],
  },
  {
    name: "Microsoft",
    aliases: ["microsoft", "outlook", "office 365"],
    domains: ["microsoft.com", "outlook.com", "office.com"],
  },
  {
    name: "Apple",
    aliases: ["apple", "icloud"],
    domains: ["apple.com", "icloud.com"],
  },
  {
    name: "Amazon",
    aliases: ["amazon"],
    domains: ["amazon.com", "amazon.co.uk"],
  },
  { name: "PayPal", aliases: ["paypal"], domains: ["paypal.com"] },
];

type HeaderInput =
  Map<string, string[]> | Record<string, string | string[] | undefined>;

@Injectable()
export class SenderIdentityRiskService {
  assess(input: {
    displayName?: string;
    fromEmail: string;
    labels: string[];
    headers: HeaderInput;
  }): IdentityAssessment {
    const fromDomain = this.domainFromEmail(input.fromEmail);
    const brand = this.claimedBrand(input.displayName);
    const authValues = this.values(input.headers, "authentication-results");
    const arcValues = this.values(input.headers, "arc-authentication-results");
    const authentication = this.parseAuthentication(authValues);
    const arc = this.parseAuthentication(arcValues);
    const forwarded = arc.dkim === "pass" || arc.dmarc === "pass";
    const mailingList = this.values(input.headers, "list-id").length > 0;
    const replyToEmail = this.emailFromHeader(
      this.first(input.headers, "reply-to"),
    );
    const returnPathEmail = this.emailFromHeader(
      this.first(input.headers, "return-path"),
    );
    const authenticatedDomain =
      authentication.dmarcDomain ??
      authentication.dkimDomain ??
      authentication.spfDomain;
    const evidence: IdentityEvidence[] = [];

    const add = (
      code: IdentityEvidenceCode,
      weight: number,
      detail: string,
    ) => {
      if (!evidence.some((item) => item.code === code))
        evidence.push({ code, weight, detail });
    };

    if (brand && fromDomain && !this.isApprovedDomain(fromDomain, brand)) {
      add(
        "BRAND_DOMAIN_MISMATCH",
        35,
        `${brand.name} is claimed, but the From domain is ${fromDomain}.`,
      );
      if (fromDomain.includes("xn--") || this.isLookalike(fromDomain, brand)) {
        add(
          "LOOKALIKE_DOMAIN",
          25,
          `${fromDomain} resembles an official ${brand.name} domain.`,
        );
      }
    }

    if (!forwarded && !mailingList) {
      if (authentication.dmarc === "fail")
        add("DMARC_FAILED", 30, "DMARC authentication failed.");
      if (authentication.dkim === "fail")
        add("DKIM_FAILED", 15, "DKIM authentication failed.");
      if (authentication.spf === "fail" || authentication.spf === "softfail") {
        add("SPF_FAILED", 10, "SPF authentication failed.");
      }
    }

    const authPassed =
      authentication.dmarc === "pass" || authentication.dkim === "pass";
    if (
      authPassed &&
      authenticatedDomain &&
      fromDomain &&
      !this.domainsAlign(fromDomain, authenticatedDomain)
    ) {
      add(
        "AUTH_DOMAIN_MISMATCH",
        30,
        `The authenticated domain ${authenticatedDomain} does not align with ${fromDomain}.`,
      );
    }

    if (replyToEmail) {
      const replyDomain = this.domainFromEmail(replyToEmail);
      if (
        replyDomain &&
        fromDomain &&
        !this.domainsAlign(fromDomain, replyDomain) &&
        (brand != null || authPassed) &&
        !mailingList
      ) {
        add(
          "REPLY_TO_MISMATCH",
          15,
          `Replies are directed to a different domain: ${replyDomain}.`,
        );
      }
    }

    if (returnPathEmail) {
      const returnDomain = this.domainFromEmail(returnPathEmail);
      if (
        returnDomain &&
        fromDomain &&
        !this.domainsAlign(fromDomain, returnDomain) &&
        brand != null &&
        !mailingList
      ) {
        add(
          "RETURN_PATH_MISMATCH",
          5,
          `The return path uses a different domain: ${returnDomain}.`,
        );
      }
    }

    if (input.labels.includes("SPAM")) {
      add(
        "GMAIL_SPAM_CLASSIFICATION",
        30,
        "Gmail classified this message as spam.",
      );
    }

    // Authentication failures are correlated; count no more than the strongest
    // 30 points from SPF/DKIM/DMARC while retaining every explanation.
    const authenticationCodes = new Set<IdentityEvidenceCode>([
      "SPF_FAILED",
      "DKIM_FAILED",
      "DMARC_FAILED",
    ]);
    const authenticationWeight = Math.max(
      0,
      ...evidence
        .filter((item) => authenticationCodes.has(item.code))
        .map((item) => item.weight),
    );
    const otherWeight = evidence
      .filter((item) => !authenticationCodes.has(item.code))
      .reduce((total, item) => total + item.weight, 0);
    const score = Math.min(100, authenticationWeight + otherWeight);
    const level = this.levelFor(score);
    const officialBrandDomain = Boolean(
      brand && fromDomain && this.isApprovedDomain(fromDomain, brand),
    );
    const alignedAuthentication =
      authentication.dmarc === "pass" ||
      (authentication.dkim === "pass" &&
        authenticatedDomain != null &&
        fromDomain != null &&
        this.domainsAlign(fromDomain, authenticatedDomain));
    const status =
      score >= 50
        ? IdentityStatus.SUSPICIOUS
        : alignedAuthentication && (!brand || officialBrandDomain)
          ? IdentityStatus.VERIFIED
          : IdentityStatus.UNVERIFIED;

    return {
      score,
      level,
      status,
      claimedBrand: brand?.name,
      authenticatedDomain,
      replyToEmail,
      evidence,
    };
  }

  private levelFor(score: number): IdentityRiskLevel {
    if (score >= 75) return IdentityRiskLevel.HIGH;
    if (score >= 50) return IdentityRiskLevel.POSSIBLE_IMPERSONATION;
    if (score >= 25) return IdentityRiskLevel.REVIEW;
    return IdentityRiskLevel.LOW;
  }

  private claimedBrand(displayName?: string) {
    const value = displayName?.toLowerCase().normalize("NFKC") ?? "";
    return BRANDS.find((brand) =>
      brand.aliases.some((alias) =>
        new RegExp(`(^|[^a-z0-9])${this.escape(alias)}([^a-z0-9]|$)`, "i").test(
          value,
        ),
      ),
    );
  }

  private isApprovedDomain(domain: string, brand: BrandDefinition) {
    return brand.domains.some(
      (approved) => domain === approved || domain.endsWith(`.${approved}`),
    );
  }

  private isLookalike(domain: string, brand: BrandDefinition) {
    const label = domain.split(".")[0]?.replace(/^xn--/, "") ?? "";
    const normalized = label
      .replace(/0/g, "o")
      .replace(/1|l/g, "i")
      .replace(/[^a-z]/g, "");
    return brand.aliases.some((alias) => {
      const target = alias.replace(/[^a-z]/g, "");
      return normalized === target || this.levenshtein(normalized, target) <= 1;
    });
  }

  private parseAuthentication(values: string[]) {
    const joined = values.join("; ").toLowerCase();
    const result = (name: string) =>
      joined.match(new RegExp(`(?:^|[;\\s])${name}=([a-z]+)`))?.[1];
    const domain = (patterns: RegExp[]) => {
      for (const pattern of patterns) {
        const value = joined.match(pattern)?.[1];
        const normalized = value ? this.normalizeDomain(value) : undefined;
        if (normalized) return normalized;
      }
      return undefined;
    };
    return {
      spf: result("spf"),
      dkim: result("dkim"),
      dmarc: result("dmarc"),
      spfDomain: domain([/smtp\.mailfrom=([^;\s]+)/]),
      dkimDomain: domain([/header\.d=([^;\s]+)/]),
      dmarcDomain: domain([/header\.from=([^;\s]+)/]),
    };
  }

  private values(headers: HeaderInput, name: string): string[] {
    if (headers instanceof Map) return headers.get(name) ?? [];
    const value =
      headers[name] ??
      headers[
        Object.keys(headers).find((key) => key.toLowerCase() === name) ?? ""
      ];
    return Array.isArray(value) ? value.filter(Boolean) : value ? [value] : [];
  }

  private first(headers: HeaderInput, name: string) {
    return this.values(headers, name)[0];
  }

  private emailFromHeader(value?: string) {
    return value
      ?.match(/[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9._-]+/i)?.[0]
      ?.toLowerCase();
  }

  private domainFromEmail(email: string) {
    return this.normalizeDomain(email.split("@").pop());
  }

  private normalizeDomain(value?: string) {
    if (!value) return undefined;
    const clean = value
      .trim()
      .toLowerCase()
      .replace(/^<|>$/g, "")
      .replace(/\.$/, "");
    const ascii = domainToASCII(clean);
    return ascii && /^[a-z0-9.-]+$/.test(ascii) ? ascii : undefined;
  }

  private domainsAlign(first: string, second: string) {
    return (
      first === second ||
      first.endsWith(`.${second}`) ||
      second.endsWith(`.${first}`)
    );
  }

  private levenshtein(first: string, second: string) {
    const row = Array.from({ length: second.length + 1 }, (_, index) => index);
    for (let i = 1; i <= first.length; i += 1) {
      let previous = row[0];
      row[0] = i;
      for (let j = 1; j <= second.length; j += 1) {
        const current = row[j];
        row[j] = Math.min(
          row[j] + 1,
          row[j - 1] + 1,
          previous + (first[i - 1] === second[j - 1] ? 0 : 1),
        );
        previous = current;
      }
    }
    return row[second.length];
  }

  private escape(value: string) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }
}
