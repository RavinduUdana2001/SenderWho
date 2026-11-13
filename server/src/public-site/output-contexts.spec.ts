import { Parser } from "htmlparser2";
import { oauthResultPage } from "../auth/auth.controller";
import {
  supportMailto,
  renderHomePage,
  renderPrivacyPage,
  renderTermsPage,
  renderSupportPage,
  renderDeleteAccountPage,
} from "./public-site.pages";

const payloads = [
  '<img src=x onerror="alert(1)">',
  '"><svg onload=alert(1)>',
  "</script><script>alert(1)</script>",
  "javascript:alert(1)",
  "'`&<>\"\\\u2028\u2029",
];

function inspect(html: string) {
  const tags: { name: string; attributes: Record<string, string> }[] = [];
  const scripts: string[] = [];
  const styles: string[] = [];
  let active: "script" | "style" | undefined;
  const parser = new Parser({
    onopentag(name, attributes) {
      tags.push({ name, attributes });
      if (name === "script" || name === "style") {
        active = name;
        (name === "script" ? scripts : styles).push("");
      }
    },
    ontext(text) {
      if (active) {
        const values = active === "script" ? scripts : styles;
        values[values.length - 1] += text;
      }
    },
    onclosetag(name) {
      if (name === active) active = undefined;
    },
  });
  parser.write(html);
  parser.end();
  return {
    tags,
    scripts,
    styles,
    structure: tags.map((t) => [t.name, Object.keys(t.attributes).sort()]),
  };
}

describe("context-aware XSS output handling", () => {
  const safe = {
    legalName: "SenderWho",
    supportEmail: "support@example.test",
    effectiveDate: "2026-08-01",
  };
  const pages = [
    renderHomePage,
    renderPrivacyPage,
    renderTermsPage,
    renderSupportPage,
    renderDeleteAccountPage,
  ];

  it.each(pages.map((render) => [render.name, render] as const))(
    "keeps HTML, quoted attributes, URLs and CSS safe in %s",
    (_name, render) => {
      const baseline = inspect(render({ ...safe, supportEmail: "" }));
      for (const payload of payloads) {
        const parsed = inspect(
          render({
            legalName: payload,
            supportEmail: payload,
            effectiveDate: payload,
          }),
        );
        expect(parsed.structure).toEqual(baseline.structure);
        expect(parsed.scripts).toEqual([]);
        expect(parsed.styles).toEqual(baseline.styles);
        for (const tag of parsed.tags) {
          expect(
            Object.keys(tag.attributes).some((name) => /^on/i.test(name)),
          ).toBe(false);
          if (tag.attributes.href) {
            const href = tag.attributes.href;
            expect(
              href.startsWith("/") ||
                href.startsWith("#") ||
                href.startsWith("https://senderwho.com/") ||
                href === supportMailto(payload),
            ).toBe(true);
          }
        }
      }
    },
  );

  it.each([true, false])(
    "keeps OAuth JavaScript, URLs and attributes independent of input (success=%s)",
    (success) => {
      const baseline = inspect(oauthResultPage(success, "Title", "Message"));
      for (const payload of payloads) {
        const parsed = inspect(oauthResultPage(success, payload, payload));
        expect(parsed.structure).toEqual(baseline.structure);
        expect(parsed.scripts).toEqual(baseline.scripts);
        expect(parsed.scripts).toHaveLength(1);
        for (const tag of parsed.tags) {
          expect(
            Object.keys(tag.attributes).some((name) => /^on/i.test(name)),
          ).toBe(false);
          if (tag.attributes.href)
            expect(tag.attributes.href).toBe(
              `senderwho://oauth/callback?status=${success ? "success" : "failed"}`,
            );
        }
        const script = parsed.tags.find((t) => t.name === "script")!;
        expect(script.attributes.nonce).toMatch(/^[A-Za-z0-9+/]{24}$/);
        const csp = parsed.tags.find(
          (t) =>
            t.name === "meta" &&
            t.attributes["http-equiv"] === "Content-Security-Policy",
        )!;
        expect(csp.attributes.content).toContain(
          `script-src 'nonce-${script.attributes.nonce}'`,
        );
      }
    },
  );

  it("constructs a mailto URL by encoding the local part and rejects header/scheme injection", () => {
    expect(supportMailto("support+tag&team@example.test")).toBe(
      "mailto:support%2Btag%26team@example.test",
    );
    for (const value of [
      "javascript:alert(1)",
      "a@example.test?subject=x",
      "a@example.test#x",
      "a@example.test\r\nBcc:b@evil.test",
      "a@b.test,c@d.test",
    ]) {
      expect(supportMailto(value)).toBeUndefined();
      expect(
        inspect(renderSupportPage({ ...safe, supportEmail: value })).tags.some(
          (t) => t.attributes.href?.startsWith("mailto:"),
        ),
      ).toBe(false);
    }
  });

  it("generates a fresh OAuth script nonce on each response", () => {
    const nonce = () =>
      inspect(oauthResultPage(true, "T", "M")).tags.find(
        (t) => t.name === "script",
      )!.attributes.nonce;
    expect(nonce()).not.toBe(nonce());
  });
});
