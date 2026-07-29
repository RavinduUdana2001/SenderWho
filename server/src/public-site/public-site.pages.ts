export interface PublicSiteDetails {
  legalName: string;
  supportEmail: string;
  effectiveDate: string;
}

type PageName = "home" | "privacy" | "terms" | "support" | "delete-account";

const pagePaths: Record<PageName, string> = {
  home: "/",
  privacy: "/privacy",
  terms: "/terms",
  support: "/support",
  "delete-account": "/delete-account",
};

export function renderHomePage(details: PublicSiteDetails): string {
  return renderPage({
    details,
    page: "home",
    title: "Understand your inbox",
    description:
      "SenderWho helps you understand email senders, organize messages, improve inbox health, and manage mailing-list subscriptions.",
    body: `
      <main id="main">
        <section class="hero wrap">
          <div class="eyebrow">A clearer, safer inbox</div>
          <h1>Know who is behind every email.</h1>
          <p class="lead">SenderWho brings sender context, inbox organization, security signals, and mailing-list controls into one focused mobile experience.</p>
          <div class="actions">
            <a class="button primary" href="/support">Get support</a>
            <a class="button secondary" href="/privacy">How we protect data</a>
          </div>
          <div class="trust-row" aria-label="Product principles">
            <span>Private by design</span>
            <span>User-controlled connections</span>
            <span>No advertising data sales</span>
          </div>
        </section>

        <section class="section wrap" aria-labelledby="features-title">
          <div class="section-heading">
            <div class="eyebrow">One place to take control</div>
            <h2 id="features-title">Useful context without inbox clutter</h2>
          </div>
          <div class="grid three">
            ${featureCard(
              "Sender intelligence",
              "See the people, companies, and newsletters reaching your inbox, with useful identity and safety context.",
            )}
            ${featureCard(
              "Inbox health",
              "Review organization, subscription, and security signals with clear actions and progress.",
            )}
            ${featureCard(
              "Subscription controls",
              "Review supported mailing lists and request an unsubscribe without searching through old messages.",
            )}
          </div>
        </section>

        <section class="section wrap">
          <div class="split-panel">
            <div>
              <div class="eyebrow">You remain in control</div>
              <h2>Connect only when you choose.</h2>
            </div>
            <div>
              <p>SenderWho uses provider authorization instead of asking for your mailbox password. You can disconnect an email account, export your SenderWho data, or delete your SenderWho account from the app.</p>
              <a class="text-link" href="/delete-account">Read account deletion instructions <span aria-hidden="true">→</span></a>
            </div>
          </div>
        </section>
      </main>`,
  });
}

export function renderPrivacyPage(details: PublicSiteDetails): string {
  return renderPolicyPage({
    details,
    page: "privacy",
    title: "Privacy Policy",
    description:
      "How SenderWho collects, uses, protects, retains, and deletes information.",
    intro:
      "This policy explains how SenderWho processes information when you use the service.",
    sections: [
      [
        "1. Information we process",
        `<p>We process the information needed to provide SenderWho, including:</p>
        ${list([
          "Account and authorization information, such as your email address, provider account identifier, authorization tokens, connected-account status, and app session information.",
          "Mailbox information needed for requested features, such as sender details, message identifiers, subject lines, snippets, dates, labels, mailing-list headers, security headers, attachment indicators, and message size.",
          "Message content when it is necessary to display a message or perform an action you request.",
          "Your choices and activity in SenderWho, such as trusted senders, categories, cleanup actions, unsubscribe requests, settings, and security alerts.",
          "Operational and security information, such as request identifiers, job status, error category, device information supplied by the app, and audit events.",
        ])}`,
      ],
      [
        "2. How we use information",
        `<p>We use this information to connect your chosen mailbox, synchronize and organize messages, explain senders, calculate inbox-health signals, carry out actions you request, protect accounts, diagnose service problems, provide support, and comply with applicable law.</p>
        <p>We do not sell personal information or use mailbox data for third-party advertising.</p>`,
      ],
      [
        "3. Provider access",
        `<p>Mailbox access is authorized through the relevant email provider. SenderWho requests only the permissions needed for enabled features. Authorization credentials are stored in encrypted form. You can disconnect a provider account in SenderWho and can also remove SenderWho access from your provider account settings.</p>`,
      ],
      [
        "4. Sharing and service providers",
        `<p>Information may be processed by infrastructure, database, security, and support providers acting for us, and by your email provider when an action is carried out. We may also disclose information when required by law, to protect users or the service, or as part of a business transfer subject to appropriate safeguards.</p>`,
      ],
      [
        "5. Retention",
        `<p>We retain information only as long as needed for the service, security, support, and legal obligations. Current service defaults retain synchronized message records for up to 365 days, background-job records for up to 90 days, and audit records for the configured security-retention period. Authorization data is retained while the connection is active. These periods may be shortened or extended when necessary for security, legal, or operational reasons.</p>`,
      ],
      [
        "6. Security",
        `<p>We use measures designed to protect information, including encrypted transport, encrypted provider credentials, access controls, bounded sessions, audit logging, and rate limits. No system is completely secure, so users should also protect their device and email-provider account.</p>`,
      ],
      [
        "7. Your choices and rights",
        `<p>You can review connected accounts, disconnect a mailbox, change supported preferences, export SenderWho data, and delete your SenderWho account in the app. Depending on your location, you may also have rights to request access, correction, deletion, restriction, or a copy of personal information.</p>
        <p>See the <a href="/delete-account">account deletion page</a> for instructions.</p>`,
      ],
      [
        "8. Children",
        `<p>SenderWho is not directed to children under 13, and we do not knowingly collect their personal information. A higher minimum age may apply where local law requires it.</p>`,
      ],
      [
        "9. Changes and contact",
        `<p>We may update this policy as the service or law changes. The effective date on this page identifies the current version. Questions and privacy requests can be sent using the contact details below.</p>
        ${contactBlock(details)}`,
      ],
    ],
  });
}

export function renderTermsPage(details: PublicSiteDetails): string {
  return renderPolicyPage({
    details,
    page: "terms",
    title: "Terms of Service",
    description: "The terms that apply when you use SenderWho.",
    intro:
      "By using SenderWho, you agree to these terms. If you do not agree, do not use the service.",
    sections: [
      [
        "1. Eligibility and your account",
        `<p>You must be legally able to agree to these terms and meet the minimum age required in your location. You are responsible for protecting your device, email-provider account, and access to SenderWho.</p>`,
      ],
      [
        "2. Permission to access your mailbox",
        `<p>You authorize SenderWho to access and process the connected mailbox only to provide the features you choose. You represent that you are permitted to connect and manage that mailbox. You can withdraw access by disconnecting the account or removing SenderWho in your provider settings.</p>`,
      ],
      [
        "3. Acceptable use",
        `<p>You must not misuse the service, access another person's account without permission, interfere with security or operation, attempt to extract secrets or source code unlawfully, send abusive or unlawful requests, or use SenderWho in a way that violates applicable law or provider rules.</p>`,
      ],
      [
        "4. Email actions",
        `<p>SenderWho can help you organize messages and request actions such as cleanup or unsubscribe. Results depend on your provider, the sender, network availability, and the information in each message. Review important actions before confirming them. SenderWho does not control third-party senders and cannot guarantee that every unsubscribe request will be honored.</p>`,
      ],
      [
        "5. Third-party services",
        `<p>Email providers and other third-party services have their own terms and privacy practices. SenderWho is not responsible for those services, their availability, or changes to their APIs and permissions.</p>`,
      ],
      [
        "6. Service changes and availability",
        `<p>We may improve, add, suspend, or remove features. We work to provide a reliable service but do not promise uninterrupted or error-free operation. We may limit access to protect users, comply with law, perform maintenance, or prevent abuse.</p>`,
      ],
      [
        "7. Ownership",
        `<p>You retain your rights in your information. SenderWho and its software, design, branding, and documentation are owned by ${escapeHtml(
          details.legalName,
        )} or its licensors. These terms give you a limited, personal, revocable right to use the service.</p>`,
      ],
      [
        "8. Suspension, termination, and deletion",
        `<p>You may stop using SenderWho at any time and can delete your account in the app. We may suspend or terminate access for serious or repeated violations, security risks, legal requirements, or discontinuation of the service.</p>`,
      ],
      [
        "9. Disclaimers and liability",
        `<p>To the extent permitted by law, SenderWho is provided “as is” and “as available,” without implied warranties. ${escapeHtml(
          details.legalName,
        )} is not liable for indirect, incidental, special, consequential, or punitive damages, or for loss caused by third-party services, except where liability cannot legally be excluded.</p>`,
      ],
      [
        "10. Changes and contact",
        `<p>We may update these terms. Continued use after an update takes effect means you accept the revised terms where permitted by law. Questions can be sent using the contact details below.</p>
        ${contactBlock(details)}`,
      ],
    ],
  });
}

export function renderSupportPage(details: PublicSiteDetails): string {
  return renderPage({
    details,
    page: "support",
    title: "Support",
    description:
      "Help with connecting an account, inbox synchronization, unsubscribe requests, privacy, and account deletion.",
    body: `
      <main id="main">
        <section class="page-hero wrap">
          <div class="eyebrow">SenderWho help</div>
          <h1>How can we help?</h1>
          <p class="lead">Find quick steps for common issues or contact the SenderWho support team.</p>
        </section>

        <section class="section compact wrap">
          <div class="grid two">
            ${supportCard(
              "Account will not connect",
              "Confirm the device has internet access, finish the provider consent screen, then return to SenderWho. If access was previously removed in provider settings, connect again from the app.",
            )}
            ${supportCard(
              "Inbox is still synchronizing",
              "Keep the account connected and allow the current scan to finish. Provider rate limits can temporarily slow a large inbox. Use Retry once after the wait message clears.",
            )}
            ${supportCard(
              "An unsubscribe could not finish",
              "Some senders do not provide a valid automatic method. Retry after a short wait. When automatic unsubscribe is unavailable, open the sender's latest message and use its verified unsubscribe option.",
            )}
            ${supportCard(
              "Privacy or account deletion",
              "Open Profile, choose Privacy & security, and use Download or share data export or Delete SenderWho account. More details are available on the deletion page.",
              `<a class="text-link" href="/delete-account">Account deletion instructions <span aria-hidden="true">→</span></a>`,
            )}
          </div>
        </section>

        <section class="section wrap">
          <div class="contact-panel">
            <div>
              <div class="eyebrow">Contact support</div>
              <h2>Still need help?</h2>
              <p>Include the account provider, device type, the action you attempted, and the approximate time. Do not send passwords, authorization codes, access tokens, or full private email content.</p>
            </div>
            ${contactAction(details)}
          </div>
        </section>
      </main>`,
  });
}

export function renderDeleteAccountPage(details: PublicSiteDetails): string {
  return renderPage({
    details,
    page: "delete-account",
    title: "Delete your account",
    description:
      "How to permanently delete a SenderWho account and associated SenderWho data.",
    body: `
      <main id="main">
        <section class="page-hero wrap">
          <div class="eyebrow">Account controls</div>
          <h1>Delete your SenderWho account</h1>
          <p class="lead">You can permanently delete your SenderWho account from inside the mobile app.</p>
        </section>

        <section class="section compact wrap">
          <div class="step-panel">
            <h2>Delete in the app</h2>
            <ol class="steps">
              <li><span>1</span><div><strong>Open your profile</strong><p>Launch SenderWho and open the Profile screen.</p></div></li>
              <li><span>2</span><div><strong>Open Privacy &amp; security</strong><p>Select Privacy &amp; security under Manage account.</p></div></li>
              <li><span>3</span><div><strong>Choose Delete SenderWho account</strong><p>Scroll to Your Data and select Delete SenderWho account.</p></div></li>
              <li><span>4</span><div><strong>Confirm permanent deletion</strong><p>Review the warning and choose Delete permanently.</p></div></li>
            </ol>
          </div>
        </section>

        <section class="section compact wrap">
          <div class="grid two">
            ${supportCard(
              "What is deleted",
              "Your SenderWho account and associated SenderWho records are deleted, active app sessions are revoked, queued SenderWho jobs are canceled, and connected accounts are disconnected. Provider-access revocation is attempted where the provider supports it.",
            )}
            ${supportCard(
              "What is not deleted",
              "Deleting SenderWho does not delete the original messages in your email-provider mailbox. Actions you already completed in your mailbox, such as trashing a message, are not automatically reversed.",
            )}
          </div>
        </section>

        <section class="section wrap">
          <div class="contact-panel">
            <div>
              <div class="eyebrow">Cannot access the app?</div>
              <h2>Request deletion through support</h2>
              <p>Contact us from the email address associated with the SenderWho account. We will need to verify account ownership before processing a request.</p>
            </div>
            ${contactAction(details, "Request account deletion")}
          </div>
        </section>
      </main>`,
  });
}

function renderPolicyPage(input: {
  details: PublicSiteDetails;
  page: PageName;
  title: string;
  description: string;
  intro: string;
  sections: [string, string][];
}): string {
  const effectiveDate = formatDate(input.details.effectiveDate);
  return renderPage({
    ...input,
    body: `
      <main id="main">
        <section class="page-hero policy-hero wrap">
          <div class="eyebrow">Legal</div>
          <h1>${escapeHtml(input.title)}</h1>
          <p class="lead">${escapeHtml(input.intro)}</p>
          <p class="effective">Effective: ${escapeHtml(effectiveDate)}</p>
        </section>
        <div class="policy-layout wrap">
          <aside class="policy-summary" aria-label="Policy summary">
            <strong>In short</strong>
            <p>SenderWho uses information to provide the inbox features you request, protect the service, and support your account.</p>
            <a class="text-link" href="/support">Contact support <span aria-hidden="true">→</span></a>
          </aside>
          <article class="policy">
            ${input.sections
              .map(
                ([heading, content]) =>
                  `<section><h2>${escapeHtml(heading)}</h2>${content}</section>`,
              )
              .join("")}
          </article>
        </div>
      </main>`,
  });
}

function renderPage(input: {
  details: PublicSiteDetails;
  page: PageName;
  title: string;
  description: string;
  body: string;
}): string {
  const title =
    input.page === "home"
      ? "SenderWho — Understand your inbox"
      : `${input.title} — SenderWho`;
  const canonical = `https://senderwho.com${pagePaths[input.page]}`;
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <meta name="description" content="${escapeHtml(input.description)}">
  <meta name="theme-color" content="#071225">
  <link rel="canonical" href="${canonical}">
  <style>${styles}</style>
</head>
<body>
  <a class="skip-link" href="#main">Skip to content</a>
  <header class="site-header">
    <div class="nav wrap">
      <a class="brand" href="/" aria-label="SenderWho home"><span class="brand-mark" aria-hidden="true">S</span><span>SenderWho</span></a>
      <nav aria-label="Primary navigation">
        ${navLink("/", "Home", input.page === "home")}
        ${navLink("/privacy", "Privacy", input.page === "privacy")}
        ${navLink("/terms", "Terms", input.page === "terms")}
        ${navLink("/support", "Support", input.page === "support")}
      </nav>
    </div>
  </header>
  ${input.body}
  <footer>
    <div class="footer-grid wrap">
      <div><a class="brand footer-brand" href="/"><span class="brand-mark" aria-hidden="true">S</span><span>SenderWho</span></a><p>A clearer way to understand and manage your inbox.</p></div>
      <div class="footer-links">
        <a href="/privacy">Privacy</a>
        <a href="/terms">Terms</a>
        <a href="/support">Support</a>
        <a href="/delete-account">Delete account</a>
      </div>
    </div>
    <div class="footer-bottom wrap">© ${new Date().getUTCFullYear()} ${escapeHtml(
      input.details.legalName,
    )}. All rights reserved.</div>
  </footer>
</body>
</html>`;
}

function navLink(path: string, label: string, active: boolean): string {
  return `<a href="${path}"${active ? ' aria-current="page"' : ""}>${label}</a>`;
}

function featureCard(title: string, body: string): string {
  return `<article class="feature-card"><span class="card-dot" aria-hidden="true"></span><h3>${title}</h3><p>${body}</p></article>`;
}

function supportCard(title: string, body: string, extra = ""): string {
  return `<article class="support-card"><h2>${title}</h2><p>${body}</p>${extra}</article>`;
}

function list(items: string[]): string {
  return `<ul>${items.map((item) => `<li>${item}</li>`).join("")}</ul>`;
}

function contactBlock(details: PublicSiteDetails): string {
  if (!details.supportEmail) {
    return `<p><strong>Contact:</strong> Visit <a href="/support">SenderWho Support</a>.</p>`;
  }
  const email = escapeHtml(details.supportEmail);
  return `<p><strong>Contact:</strong> <a href="mailto:${email}">${email}</a></p>`;
}

function contactAction(
  details: PublicSiteDetails,
  label = "Email support",
): string {
  if (!details.supportEmail) {
    return `<a class="button secondary disabled" href="/support" aria-disabled="true">Support email coming soon</a>`;
  }
  return `<a class="button primary" href="mailto:${escapeHtml(
    details.supportEmail,
  )}">${escapeHtml(label)}</a>`;
}

function formatDate(value: string): string {
  const date = new Date(`${value}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
    timeZone: "UTC",
  }).format(date);
}

export function escapeHtml(value: string): string {
  return value.replace(
    /[&<>"']/g,
    (character) =>
      ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;",
      })[character]!,
  );
}

const styles = `
:root {
  color-scheme: dark;
  --bg: #050b18;
  --surface: #0b1931;
  --surface-2: #102343;
  --line: #20385e;
  --text: #f7f9ff;
  --muted: #a9b8d3;
  --primary: #5275ff;
  --primary-light: #91a7ff;
  --success: #54d6a2;
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}
* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body { margin: 0; background: radial-gradient(circle at 80% -10%, #102c4f 0, transparent 34rem), var(--bg); color: var(--text); line-height: 1.65; }
a { color: var(--primary-light); }
a:hover { color: #c1ccff; }
.wrap { width: min(1120px, calc(100% - 40px)); margin-inline: auto; }
.skip-link { position: fixed; left: 16px; top: -80px; z-index: 20; background: white; color: #050b18; padding: 10px 14px; border-radius: 8px; }
.skip-link:focus { top: 16px; }
.site-header { position: sticky; top: 0; z-index: 10; border-bottom: 1px solid rgba(98, 126, 174, .22); background: rgba(5, 11, 24, .88); backdrop-filter: blur(16px); }
.nav { min-height: 72px; display: flex; align-items: center; justify-content: space-between; gap: 24px; }
.brand { display: inline-flex; gap: 10px; align-items: center; color: var(--text); text-decoration: none; font-size: 1.1rem; font-weight: 760; letter-spacing: -.02em; }
.brand-mark { display: grid; place-items: center; width: 34px; height: 34px; border-radius: 11px; background: linear-gradient(145deg, #4165ff, #6e8bff); box-shadow: 0 8px 28px rgba(82, 117, 255, .28); }
nav { display: flex; align-items: center; gap: 8px; }
nav a { padding: 8px 12px; border-radius: 9px; color: var(--muted); text-decoration: none; font-size: .93rem; font-weight: 650; }
nav a:hover, nav a[aria-current="page"] { color: var(--text); background: var(--surface-2); }
.hero { padding-block: clamp(86px, 13vw, 150px) clamp(72px, 10vw, 120px); text-align: center; }
.hero h1, .page-hero h1 { max-width: 900px; margin: 12px auto 22px; font-size: clamp(2.7rem, 7vw, 5.3rem); line-height: 1.02; letter-spacing: -.055em; }
.page-hero { padding-block: clamp(68px, 10vw, 108px) 64px; }
.page-hero h1 { margin-inline: 0; max-width: 820px; font-size: clamp(2.5rem, 6vw, 4.5rem); }
.eyebrow { color: var(--success); font-size: .78rem; font-weight: 800; letter-spacing: .13em; text-transform: uppercase; }
.lead { max-width: 760px; margin: 0 auto; color: var(--muted); font-size: clamp(1.05rem, 2vw, 1.3rem); }
.page-hero .lead { margin-inline: 0; }
.effective { color: var(--muted); font-size: .92rem; margin-top: 18px; }
.actions { display: flex; justify-content: center; flex-wrap: wrap; gap: 12px; margin-top: 34px; }
.button { display: inline-flex; justify-content: center; align-items: center; min-height: 48px; padding: 11px 20px; border-radius: 13px; text-decoration: none; font-weight: 750; }
.button.primary { color: white; background: var(--primary); box-shadow: 0 12px 32px rgba(82, 117, 255, .24); }
.button.secondary { color: var(--text); background: var(--surface-2); border: 1px solid var(--line); }
.button.disabled { color: var(--muted); cursor: default; }
.trust-row { display: flex; justify-content: center; flex-wrap: wrap; gap: 12px 26px; margin-top: 38px; color: var(--muted); font-size: .9rem; }
.trust-row span::before { content: "✓"; color: var(--success); margin-right: 7px; }
.section { padding-block: 70px; }
.section.compact { padding-block: 30px 70px; }
.section-heading { max-width: 700px; margin-bottom: 30px; }
h2 { margin: 8px 0 13px; font-size: clamp(1.65rem, 3vw, 2.35rem); line-height: 1.18; letter-spacing: -.035em; }
h3 { margin: 20px 0 8px; font-size: 1.2rem; }
p { color: var(--muted); }
.grid { display: grid; gap: 18px; }
.grid.three { grid-template-columns: repeat(3, 1fr); }
.grid.two { grid-template-columns: repeat(2, 1fr); }
.feature-card, .support-card, .step-panel { border: 1px solid var(--line); border-radius: 22px; background: linear-gradient(145deg, rgba(16, 35, 67, .82), rgba(9, 23, 45, .84)); }
.feature-card, .support-card { padding: 28px; }
.feature-card p, .support-card p { margin-bottom: 0; }
.support-card h2 { font-size: 1.3rem; }
.card-dot { display: block; width: 13px; height: 13px; border-radius: 50%; background: var(--success); box-shadow: 0 0 0 7px rgba(84, 214, 162, .1); }
.split-panel, .contact-panel { display: grid; grid-template-columns: 1fr 1fr; align-items: center; gap: clamp(28px, 8vw, 100px); padding: clamp(30px, 6vw, 60px); border: 1px solid var(--line); border-radius: 26px; background: var(--surface); }
.text-link { display: inline-block; font-weight: 700; text-decoration: none; margin-top: 8px; }
.contact-panel .button { justify-self: end; }
.policy-layout { display: grid; grid-template-columns: 280px minmax(0, 720px); gap: clamp(38px, 8vw, 90px); align-items: start; padding-bottom: 90px; }
.policy-summary { position: sticky; top: 100px; padding: 24px; border: 1px solid var(--line); border-radius: 18px; background: var(--surface); }
.policy-summary p { font-size: .92rem; }
.policy section { margin-bottom: 42px; }
.policy h2 { font-size: 1.55rem; }
.policy li { color: var(--muted); margin-bottom: 10px; }
.policy p, .policy li { max-width: 72ch; }
.step-panel { padding: clamp(24px, 5vw, 44px); }
.steps { list-style: none; margin: 28px 0 0; padding: 0; }
.steps li { display: grid; grid-template-columns: 42px 1fr; gap: 16px; padding: 20px 0; border-top: 1px solid var(--line); }
.steps li > span { display: grid; place-items: center; width: 36px; height: 36px; border-radius: 50%; color: white; background: var(--primary); font-weight: 800; }
.steps strong { font-size: 1.05rem; }
.steps p { margin: 4px 0 0; }
footer { margin-top: 50px; border-top: 1px solid var(--line); background: #061021; }
.footer-grid { display: grid; grid-template-columns: 1fr auto; gap: 30px; padding-block: 52px 34px; }
.footer-grid p { max-width: 420px; }
.footer-links { display: grid; grid-template-columns: repeat(2, auto); align-content: start; gap: 12px 32px; }
.footer-links a { color: var(--muted); text-decoration: none; }
.footer-bottom { border-top: 1px solid var(--line); padding-block: 22px; color: var(--muted); font-size: .86rem; }
@media (max-width: 800px) {
  .grid.three, .grid.two, .split-panel, .contact-panel, .policy-layout { grid-template-columns: 1fr; }
  .policy-summary { position: static; }
  .contact-panel .button { justify-self: start; }
}
@media (max-width: 620px) {
  .wrap { width: min(100% - 28px, 1120px); }
  .nav { min-height: 64px; }
  nav { gap: 2px; }
  nav a { padding: 8px 7px; font-size: .82rem; }
  .brand > span:last-child { display: none; }
  .hero { text-align: left; }
  .hero .lead { margin-inline: 0; }
  .actions, .trust-row { justify-content: flex-start; }
  .button { width: 100%; }
  .section { padding-block: 48px; }
  .feature-card, .support-card { padding: 23px; }
  .footer-grid { grid-template-columns: 1fr; }
  .footer-links { grid-template-columns: 1fr 1fr; }
}
@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
}
`;
