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
    title: "Mobile email and sender management",
    description:
      "SenderWho is a mobile email-management application that helps users understand senders, organize Gmail messages, manage subscriptions, and perform user-requested inbox actions.",
    body: `
      <main id="main">
        <section class="hero wrap">
          <div class="eyebrow">SenderWho mobile application</div>
          <h1><span class="app-name">SenderWho</span> helps you understand and manage your inbox.</h1>
          <p class="lead">SenderWho is a mobile email-management application for people who want to identify senders, organize Gmail messages, review inbox security signals, manage subscriptions, and apply email actions they explicitly choose.</p>
          <div class="actions">
            <a class="button primary" href="/support">Get support</a>
            <a class="button secondary" href="/privacy">Read our Privacy Policy</a>
          </div>
          <div class="trust-row" aria-label="Product principles">
            <span>Private by design</span>
            <span>User-controlled connections</span>
            <span>No advertising data sales</span>
          </div>
        </section>

        <section class="section wrap" aria-labelledby="features-title">
          <div class="section-heading">
            <div class="eyebrow">Application purpose</div>
            <h2 id="features-title">What SenderWho does</h2>
            <p>SenderWho extends Gmail with visible, user-facing tools for understanding who is emailing you and taking control of your own mailbox. The public website explains the product and its data practices; mailbox connection and management happen in the SenderWho mobile app.</p>
          </div>
          <div class="grid three">
            ${featureCard(
              "Understand senders",
              "Review the people, companies, and mailing lists reaching your Gmail inbox, together with identity and security context derived from message information.",
            )}
            ${featureCard(
              "Organize your inbox",
              "Search and review messages, group senders, identify categories, and see inbox-health, cleanup, subscription, and security signals.",
            )}
            ${featureCard(
              "Take actions you choose",
              "Mark messages read or unread, archive, restore, move messages to Trash, trust or block senders, and request supported one-click unsubscribe actions.",
            )}
          </div>
        </section>

        <section class="section wrap" aria-labelledby="google-access-title">
          <div class="split-panel">
            <div>
              <div class="eyebrow">Google account access</div>
              <h2 id="google-access-title">Why SenderWho requests Gmail permission</h2>
            </div>
            <div>
              <p>When a user taps <strong>Connect Gmail</strong> in the SenderWho mobile app, SenderWho uses Google OAuth to request identity, email-address, and Gmail modify access. This permission lets SenderWho retrieve the Gmail message information needed for its inbox and sender views and perform only the read, archive, restore, Trash, organization, and cleanup actions the user requests.</p>
              <p>SenderWho does not ask for a Google password, sell Google user data, use it for advertising, or use it to train general-purpose artificial-intelligence models. Users can disconnect Gmail or delete their SenderWho account.</p>
              <a class="text-link" href="/privacy">Read how SenderWho accesses, uses, stores, and shares Google user data <span aria-hidden="true">→</span></a>
            </div>
          </div>
        </section>

        <section class="section wrap" aria-labelledby="user-control-title">
          <div class="split-panel">
            <div>
              <div class="eyebrow">You remain in control</div>
              <h2 id="user-control-title">Connect only when you choose.</h2>
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
      "This policy explains exactly how SenderWho accesses, uses, stores, shares, and deletes information when you connect an email account.",
    facts: [
      ["Stored", "Metadata and short previews"],
      ["On demand", "Message text when you open it"],
      ["Control", "Disconnect, export, or delete"],
    ],
    sections: [
      [
        "1. Who operates SenderWho",
        `<p>SenderWho is operated by ${escapeHtml(
          details.legalName,
        )}. This policy applies to the SenderWho mobile application, backend service, and public website. Contact details are provided in section 12.</p>`,
      ],
      [
        "2. Information we process",
        `<p>We process only the information needed for the user-facing SenderWho features:</p>
        ${list([
          "Account and authorization data: email address, provider account identifier, display name and avatar when supplied by the provider, granted permissions, encrypted OAuth access and refresh tokens, connection state, and app-session records.",
          "Stored mailbox metadata: provider message and thread identifiers, sender name and address, domain, subject, short snippet, date, labels or flags, message size, attachment indicator, importance state, mailing-list unsubscribe headers, and authentication or identity-risk signals.",
          "Message content on demand: when you open a message, SenderWho retrieves its text and basic addressing and attachment details from your provider, sends that result to your app, and does not save the full body or attachment content in the SenderWho database.",
          "Your instructions and preferences: sender trust or block choices, categories, read/archive/trash/restore actions, cleanup selections, unsubscribe requests, settings, exports, and security-alert status.",
          "Security and operations data: request identifiers, IP address, user agent, hashed device identifier, device name supplied by the app, session and job status, safe error category, rate-limit records, and audit events.",
        ])}`,
      ],
      [
        "3. Google and Yahoo permissions",
        `<p>SenderWho uses OAuth authorization and does not ask for or store your Google or Yahoo mailbox password.</p>
        ${list([
          "Google: SenderWho requests identity and email-address access plus the Gmail modify permission. This lets the service read the mailbox data described above and apply user-requested read, archive, trash, restore, organization, and cleanup actions.",
          "Yahoo: when Yahoo access is available, SenderWho requests OpenID identity, email and profile information, and Yahoo Mail read and write permissions. They are used for the same visible inbox, sender, organization, security, and user-requested mailbox-management features.",
        ])}
        <p>Permissions are requested during provider consent. SenderWho does not use these permissions to send marketing email or access a mailbox after its authorization credentials have been removed.</p>`,
      ],
      [
        "4. How we use information",
        `<p>We use data to authenticate you; connect and synchronize the mailbox you choose; list and display messages; identify and classify senders; calculate inbox-health, cleanup, and security signals; show trusted or blocked senders; perform the message and unsubscribe actions you select; maintain progress and retries; prevent abuse; diagnose service problems; provide support; and comply with applicable law.</p>
        <p>Blocking a sender is an instruction that allows future messages found during scans to be moved to Trash. Cleanup and one-click unsubscribe actions are presented for review before they are started. One-click unsubscribe sends the standardized request to the sender's public HTTPS unsubscribe service; whether the sender honors it is controlled by that sender.</p>`,
      ],
      [
        "5. Google API and Yahoo data limited use",
        `<p>Google and Yahoo mailbox data is used only to provide or improve the user-facing features described in this policy. We do not sell mailbox data, use it for advertising, determine creditworthiness, build advertising profiles, or use it to train general-purpose artificial-intelligence models.</p>
        <p>We do not permit employees, contractors, or other people to read mailbox content except when you affirmatively provide specific content for support, when access is necessary to investigate a security or abuse incident, when required by law, or when data has been aggregated so that it does not identify a user, subject to provider policy and applicable law.</p>`,
      ],
      [
        "6. Sharing and processors",
        `<p>We disclose data only as needed to operate the service:</p>
        ${list([
          "Your selected email provider processes authorization, mailbox reads, and mailbox changes.",
          "Hosting, database, network, and security providers process encrypted or access-controlled data on our behalf under service agreements.",
          "A sender's public unsubscribe service receives a standardized one-click request only when you ask SenderWho to unsubscribe.",
          "Authorities or other recipients may receive information when legally required, to protect users or the service, or during a business transfer with appropriate safeguards and any consent required by provider policy.",
        ])}
        <p>We do not transfer mailbox data to data brokers, advertising platforms, or unrelated third parties.</p>`,
      ],
      [
        "7. Storage, retention, and deletion",
        `<p>Full message bodies and attachment content are not stored in the SenderWho database. Stored mailbox metadata and short previews are retained under the current service default for up to 365 days based on message date. Completed background-job records are retained for up to 90 days. Security and audit records are retained for the configured audit period, currently no more than 730 days. Expired OAuth login records and expired or revoked sessions are removed on scheduled retention cycles.</p>
        <p>Encrypted provider authorization tokens are retained while a connection remains active. Disconnecting clears those tokens and stops future synchronization but does not itself erase previously synchronized SenderWho metadata. Deleting the SenderWho account deletes the user record and associated SenderWho mailbox metadata, sender records, preferences, sessions, and jobs. Where infrastructure backups exist, residual encrypted copies are isolated from normal use and expire under the infrastructure provider's backup cycle, unless longer retention is legally required.</p>`,
      ],
      [
        "8. Security",
        `<p>We use measures designed to protect information, including HTTPS/TLS transport, application-level encryption for provider credentials, hashed app refresh tokens and device identifiers, authorization checks, limited session lifetimes, audit logging, rate limits, bounded background work, and restricted production configuration. No system is completely secure, so you should also protect your device and provider account.</p>
        <p>Please do not send passwords, OAuth codes, tokens, or private message content in a support request. Suspected security issues can be reported through <a href="/support">SenderWho Support</a>.</p>`,
      ],
      [
        "9. Your controls and rights",
        `<p>You can review connected accounts and permissions, disconnect a mailbox, change supported preferences, manage trusted and blocked senders, export your SenderWho data, sign out sessions, and permanently delete your SenderWho account in the app. You can also revoke SenderWho directly in Google or Yahoo account settings.</p>
        <p>Depending on your location, you may have rights to request access, correction, deletion, restriction, objection, or a portable copy of personal information. See the <a href="/delete-account">account deletion page</a> or contact us. We may verify account ownership before acting on a request.</p>`,
      ],
      [
        "10. International processing",
        `<p>SenderWho and its service providers may process information in countries other than the one where you live. Where required, we use appropriate safeguards for international transfers and continue to protect the information as described in this policy.</p>`,
      ],
      [
        "11. Children",
        `<p>SenderWho is not directed to children under 13, and we do not knowingly collect their personal information. A higher minimum age applies where local law requires it.</p>`,
      ],
      [
        "12. Changes and contact",
        `<p>We may update this policy when the service, provider permissions, or law changes. If a change materially expands how provider data is used, we will provide notice and obtain additional consent where required before applying the new use. The effective date identifies the current version.</p>
        <p>Questions, privacy-rights requests, and security reports can be sent using the contact details below.</p>
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
        `<p>You authorize SenderWho to access and process the connected mailbox only to provide the features described in the <a href="/privacy">Privacy Policy</a> and selected by you. You represent that you own or are permitted to connect and manage that mailbox. You can withdraw access by disconnecting the account or removing SenderWho in your provider settings.</p>`,
      ],
      [
        "3. Acceptable use",
        `<p>You must not misuse the service, access another person's account without permission, interfere with security or operation, attempt to extract secrets or source code unlawfully, send abusive or unlawful requests, or use SenderWho in a way that violates applicable law or provider rules.</p>`,
      ],
      [
        "4. Email actions",
        `<p>SenderWho can help you mark, archive, restore, move messages to Trash, organize messages, block or trust senders, perform cleanup, and request supported one-click unsubscribe actions. Results depend on your provider, the sender, network availability, and the information in each message. Review important actions before confirming them. SenderWho does not control third-party senders and cannot guarantee that every unsubscribe request will be honored.</p>`,
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
  facts?: [string, string][];
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
        ${
          input.facts
            ? `<section class="policy-facts wrap" aria-label="${escapeHtml(
                input.title,
              )} highlights">${input.facts
                .map(
                  ([label, value]) =>
                    `<div><span>${escapeHtml(label)}</span><strong>${escapeHtml(
                      value,
                    )}</strong></div>`,
                )
                .join("")}</section>`
            : ""
        }
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
  <meta name="application-name" content="SenderWho">
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
a:focus-visible { outline: 3px solid var(--success); outline-offset: 3px; border-radius: 6px; }
.wrap { width: min(1120px, calc(100% - 40px)); margin-inline: auto; }
.skip-link { position: fixed; left: 16px; top: -80px; z-index: 20; background: white; color: #050b18; padding: 10px 14px; border-radius: 8px; }
.skip-link:focus { top: 16px; }
.site-header { position: sticky; top: 0; z-index: 10; border-bottom: 1px solid rgba(98, 126, 174, .22); background: rgba(5, 11, 24, .88); -webkit-backdrop-filter: blur(16px); backdrop-filter: blur(16px); }
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
.policy-facts { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; margin-top: -18px; margin-bottom: 64px; }
.policy-facts > div { display: flex; flex-direction: column; gap: 4px; min-height: 108px; justify-content: center; padding: 20px 22px; border: 1px solid var(--line); border-radius: 18px; background: var(--surface); }
.policy-facts span { color: var(--success); font-size: .76rem; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; }
.policy-facts strong { font-size: 1.02rem; }
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
  .grid.three, .grid.two, .split-panel, .contact-panel, .policy-layout, .policy-facts { grid-template-columns: 1fr; }
  .policy-summary { position: static; }
  .contact-panel .button { justify-self: start; }
  .policy-facts { margin-bottom: 44px; }
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
@media (max-width: 420px) {
  .nav { align-items: flex-start; flex-direction: column; gap: 8px; padding-block: 12px; }
  .brand > span:last-child { display: inline; }
  nav { width: 100%; justify-content: space-between; }
  nav a { padding-inline: 5px; }
}
@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
}
`;
