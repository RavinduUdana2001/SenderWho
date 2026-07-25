# SenderWho Security Assessment and Roadmap

> Historical baseline only. For the current maintainable Hostinger VPS security
> plan and the controls that may be claimed, use `docs/security_architecture.md`.
> Enterprise KMS/WAF/SIEM recommendations below are not current launch features.

Assessment date: 2026-07-19  
Scope: Flutter client, NestJS API, Prisma/MySQL data layer, Redis/BullMQ jobs,
Google OAuth/Gmail integration, local deployment configuration, and repository
security controls.

> Prompt 2 implementation update: many source-level P0 findings identified below
> have now been remediated. The current control status, remaining blockers, exact
> test results, and Prompt 3 handoff are in
> `docs/prompt2_implementation_report.md`; the target architecture is in
> `docs/security_architecture.md`. This assessment remains the original baseline.
> Current control verification and residual findings are recorded in
> `docs/production_readiness_reaudit.md`.

## Executive summary

SenderWho has a better security baseline than a typical prototype. Protected API
routes are deny-by-default, request DTOs reject unknown properties, principal
queries are normally scoped by `userId`, Google tokens are encrypted with
AES-256-GCM, application refresh tokens are stored as hashes and rotated, the
Flutter client persists only the refresh token in platform secure storage, and
the unsubscribe worker attempts to reject private-network URLs.

It is **not ready for production security sign-off**. The highest-priority gaps
are missing OAuth PKCE/nonce, no refresh-token family/reuse containment, no MFA
or recent-authentication gate for destructive Gmail operations, a possible DNS
rebinding/time-of-check-time-of-use gap in outbound unsubscribe requests, a
single environment-held encryption key without managed key rotation, HTTP being
accepted by release clients, and the absence of centralized security telemetry,
incident alerts, CI security gates, and verified production infrastructure.

No claim of complete security is made. This is a source/configuration review,
not a penetration test, cloud audit, mobile binary assessment, or Google OAuth
verification assessment.

## 1. Current architecture and data flow

```text
[User]
   |
   v
[Flutter app: Android/iOS/Web/Desktop]
   |  access JWT in memory; refresh token in secure storage
   |  HTTPS required for production (not currently enforced by client)
   v
[NestJS API]
   |-- global JWT guard (except explicitly public routes)
   |-- global DTO validation and throttling
   |-- OAuth callback/session exchange
   |-- Gmail operations and user-scoped product APIs
   |
   +--------> [Google OAuth / OpenID userinfo / Gmail API]
   |             provider tokens encrypted in the application database
   |
   +--------> [MySQL through Prisma]
   |             users, sessions, account tokens, metadata, snippets, jobs,
   |             alerts, preferences, and audit records
   |
   +--------> [Redis + BullMQ]
                 scan, cleanup, and unsubscribe jobs
                    |
                    +--> [Gmail API]
                    +--> [Sender-controlled unsubscribe HTTPS endpoint]
```

### Trust boundaries

1. User/device to Flutter application.
2. Flutter application to public API.
3. Public API to authenticated application principal.
4. API/workers to MySQL and Redis.
5. API to Google OAuth and Gmail.
6. Unsubscribe worker to an untrusted sender-controlled URL.
7. CI/CD and operators to production secrets and infrastructure.
8. Monitoring/crash tooling to potentially sensitive diagnostic data.

### Entry points

- Public health, OAuth start/callback, OAuth-session exchange, refresh, and
  logout endpoints.
- Authenticated REST endpoints for messages, content, senders, accounts,
  cleanup, unsubscribe, settings, search, and alerts.
- OAuth callbacks and Google API responses.
- Gmail message headers, snippets, MIME content, and unsubscribe URLs.
- BullMQ job payloads and scheduled inbox scans.
- Environment variables, deployment manifests, migrations, and dependencies.

### Privileged/destructive operations

- Connect or disconnect Gmail.
- Refresh/revoke SenderWho sessions.
- Read full message content on demand.
- Archive, trash, restore, and change read state in Gmail.
- Bulk cleanup and one-click unsubscribe.
- Change sender trust/block state and resolve security alerts.

## 2. Data inventory and classification

| Data | Classification | Current location | Required handling |
|---|---|---|---|
| OAuth client secrets, JWT secret, token encryption key | Highly sensitive | Server environment | Managed secret store; rotation; never in clients/logs |
| Google access/refresh tokens | Highly sensitive | MySQL, AES-256-GCM encrypted | KMS envelope encryption; restricted service identity; audited decrypt |
| SenderWho refresh tokens | Highly sensitive | Device secure storage; SHA-256 hash in MySQL | Rotation, family tracking, reuse response, device/session management |
| Access JWT | Highly sensitive, short-lived | Flutter process memory | TLS only; short lifetime; never log or persist |
| Email address, sender address, subject, snippet | Confidential personal data | MySQL and API responses | Minimize, encrypt at rest, retention/deletion, redact logs |
| Full Gmail message content | Highly confidential | Retrieved live and returned to client | Do not persist by default; no analytics/logging; secure display |
| Unsubscribe URLs | Confidential and untrusted | MySQL/job data | Treat as attacker input; SSRF-safe egress path |
| IP/device/user agent/session history | Confidential security data | Schema supports some fields; not populated | Minimize; retention; access control; privacy notice |
| Audit/security events | Confidential/integrity-critical | MySQL audit table | Append-only/tamper-evident sink; restricted reads; retention |
| Preferences and UI theme | Internal/personal | MySQL/device state | Normal authenticated controls |
| Mock/sample data | Internal/test only | Source and mock runtime | Impossible to enable in production; never mix with production data |

True end-to-end encryption is not available for Gmail data that the backend must
read to classify, synchronize, or mutate. SenderWho should promise encryption in
transit and at rest, data minimization, and tightly controlled processing—not
claim end-to-end encryption for server-processed email data.

## 3. Existing controls confirmed in source

- Global `JwtAuthGuard` denies access unless a route is explicitly public.
- Access JWTs default to 15 minutes and require an `access` token type.
- OAuth state is signed, expires in ten minutes, and is tied to a server-side
  one-time login session.
- OAuth-session exchange uses a high-entropy secret stored only as a hash and is
  atomically claimed once.
- App refresh tokens are high entropy, stored as hashes, and atomically rotated.
- Provider tokens use AES-256-GCM with random 96-bit IVs.
- Flutter persists refresh tokens through `flutter_secure_storage`; access JWTs
  remain in memory.
- Global validation uses whitelist, forbid-non-whitelisted, and transformation.
- Pagination and bulk arrays have explicit upper limits.
- Prisma is used without raw SQL in the reviewed source.
- Main resource lookups include the authenticated `userId`; representative
  cross-user negative tests exist for message operations.
- Helmet, compression, explicit production CORS validation, and throttling are
  configured.
- OAuth result values are HTML escaped and the page has a restrictive CSP.
- Google/Gmail requests have timeouts and limited retry behavior.
- Unsubscribe requires HTTPS, limits redirects, rejects credentials in URLs,
  resolves DNS, and rejects common private/reserved address ranges.
- `.env` and `.env.local` are ignored; the example file contains placeholders.
- `npm audit` on 2026-07-19 reported zero known vulnerabilities across 762
  installed production/development dependencies. This is point-in-time evidence,
  not a continuing guarantee.

## 4. Risk-ranked security gaps

Likelihood and impact use High/Medium/Low relative ratings. P0 means required
before production launch; P1 before broad rollout; P2 after reliable telemetry.

| ID | Finding | Likelihood | Impact | Priority | Standards |
|---|---|---:|---:|---:|---|
| SW-01 | Google authorization does not use PKCE and does not issue/validate an OIDC nonce. The userinfo response is trusted without validating an ID token issuer, audience, nonce, and timestamps. | Medium | High | P0 | ASVS V2; API2; MASVS-AUTH |
| SW-02 | Refresh-token rotation has no family/parent lineage. Reuse returns an error but does not identify compromise or revoke descendants/all sessions. | High | High | P0 | ASVS V3; API2; MASVS-AUTH |
| SW-03 | MFA/passkeys, recent-authentication, recovery controls, device history, and remote session management are absent. `twoFactorEnabled` is currently only a settings field. | High | High | P0/P1 | ASVS V2; API2; MASVS-AUTH |
| SW-04 | Bulk trash/cleanup, disconnect, and unsubscribe rely on possession of a bearer token; they have no step-up token, idempotency key, or replay ledger. | Medium | High | P0 | ASVS V4; API6; MASVS-AUTH |
| SW-05 | The unsubscribe worker validates one DNS resolution, but `fetch` can resolve the hostname again. DNS rebinding can create an SSRF time-of-check/time-of-use bypass. Egress is not allowlisted at infrastructure level. | Medium | High | P0 | ASVS V12; API7 |
| SW-06 | Provider-token encryption uses one static environment key. There is no KMS envelope encryption, key identifier, authenticated record context, rotation workflow, or audited decrypt operation. | Medium | High | P0 | ASVS V6/V8; MASVS-CRYPTO |
| SW-07 | Flutter defaults to an HTTP API URL and has no release-time HTTPS assertion. A release built without the correct dart define could transmit sessions in cleartext on platforms that permit it. | Medium | Critical | P0 | ASVS V9; MASVS-NETWORK |
| SW-08 | Throttling is one general 120/minute policy with default storage. Authentication/exchange/refresh and destructive endpoints lack stricter per-IP, per-account, per-device limits and distributed enforcement. | High | High | P0 | ASVS V2/V13; API4 |
| SW-09 | Audit coverage is partial, logs are not structured with correlation IDs, IP/session context is not populated, and no SIEM alert catalogue or tamper-resistant sink exists. | High | High | P0 | ASVS V7; API10 |
| SW-10 | Swagger is registered unconditionally, including production. It increases endpoint discovery and may encourage handling live bearer tokens in a production documentation UI. | Medium | Medium | P0 | ASVS V14; API8 |
| SW-11 | Database and backup encryption, TLS certificate verification, private networking, runtime/migration identity separation, audit settings, restore tests, and managed Redis authentication are not represented in deployable production configuration. | Medium | Critical | P0 | ASVS V8/V9; API8 |
| SW-12 | Local Docker publishes MySQL and Redis and uses fixed development passwords; Redis has no password/TLS. This is acceptable only for isolated local development and needs strong production guardrails. | Medium | High | P0 | ASVS V8/V14 |
| SW-13 | No CI security workflow is present for secret scanning, SAST, dependency review, SBOM, container/IaC scanning, DAST, or release gating. | High | High | P0 | ASVS V14; MASVS-CODE |
| SW-14 | Full message content can be retrieved through the API. It is rendered as Flutter text, reducing direct HTML XSS risk, but response caching, clipboard/screenshot exposure, application-switcher previews, and retention expectations are not controlled. | Medium | High | P1 | ASVS V8/V14; MASVS-STORAGE/PRIVACY |
| SW-15 | Audit metadata stores email addresses and some provider errors are persisted. A formal redaction policy and automated tests preventing token/message leakage are absent. | Medium | High | P0 | ASVS V7/V8; MASVS-PRIVACY |
| SW-16 | Access JWTs remain usable until expiry after logout/session revocation. There is no session/security-version claim for immediate invalidation after account compromise. | Medium | Medium | P1 | ASVS V3; API2 |
| SW-17 | User identities are keyed by email without an explicit normalized-email strategy, while the stable Google `sub` is attached to the email account rather than the primary identity. Account-linking rules need formalization. | Low/Medium | High | P0 | ASVS V2; API2 |
| SW-18 | `MOCK_DATA_ENABLED=true` bypasses production environment validation. There is no explicit startup failure preventing mock mode in `NODE_ENV=production`. | Medium | High | P0 | ASVS V14; API8 |
| SW-19 | OAuth start returns a polling secret to any caller and all public auth endpoints share the broad global rate limit. Enumeration is limited by high entropy but automated session/database exhaustion remains possible. | High | Medium | P0 | ASVS V2/V13; API4 |
| SW-20 | No formal retention job, account export/deletion implementation, legal basis/consent record, or tested provider-token revocation workflow exists. | Medium | High | P0/P1 | ASVS V8; MASVS-PRIVACY |
| SW-21 | No mobile attestation, rooted/jailbroken-device risk signal, anti-automation telemetry, or release binary security verification exists. | Medium | Medium | P1 | MASVS-RESILIENCE |
| SW-22 | Current sender risk values are deterministic product data; there is no account-takeover/fraud telemetry pipeline, explainable risk engine, model governance, or false-positive measurement. | High | Medium | P2 | API2/API4; privacy governance |

### Injection and common-attack assessment

- **SQL injection:** no raw Prisma query was found; risk is currently low. Keep
  raw SQL prohibited by lint/review unless parameterized and tested.
- **XSS:** OAuth callback output is escaped and has CSP. Flutter renders message
  bodies as text, not executable HTML. Flutter web still needs deployment-level
  CSP and regression tests before sign-off.
- **CSRF:** bearer tokens are sent in authorization headers rather than cookies,
  so classic cookie CSRF is not the primary risk. Reassess if web authentication
  moves to cookies.
- **Mass assignment:** global DTO whitelisting is strong. Continue using explicit
  DTOs and response selects.
- **Brute force/bots:** only generic throttling exists; targeted and distributed
  controls are required.
- **Command/path/deserialization injection:** no command execution or filesystem
  upload path was found in reviewed runtime code. Queue and JSON boundaries still
  need schema/version validation.
- **IDOR/BOLA:** reviewed public-facing services generally scope resources by
  `userId`. Expand cross-tenant tests to every resource and mutation.

## 5. STRIDE threat model

| Category | Representative threat | Current mitigation | Required next control |
|---|---|---|---|
| Spoofing | Stolen refresh token, OAuth code interception, forged callback, automated login sessions | Signed state, one-time exchange secret, JWT verification, secure storage | PKCE/nonce, token families, MFA/passkeys, device/session history, auth-specific limits |
| Tampering | Modified request bodies, forged job payloads, changed audit records | DTO whitelist, JWT guard, Prisma, queue IDs | Idempotency/replay ledger, queue payload schemas, append-only remote audit sink |
| Repudiation | User or operator denies destructive Gmail action | Some audit rows | Correlation IDs, actor/session/device context, immutable audit retention |
| Information disclosure | OAuth token, message content, snippet, email, secret, or backup leak | AES-GCM token encryption, short JWT, secure storage, ignored env files | KMS, redaction tests, private network/TLS, log controls, screenshot/cache protection |
| Denial of service | OAuth-session creation flood, search/bulk abuse, Gmail quota exhaustion, queue flood | General throttle, pagination/bulk limits, retries | Distributed route-specific quotas, WAF/DDoS, queue quotas/backpressure, circuit breakers |
| Elevation of privilege | BOLA, stolen bearer token performs bulk delete, worker SSRF reaches metadata service | Global guard and user-scoped queries, SSRF address checks | Complete ownership test matrix, step-up auth, DNS-safe egress proxy, cloud egress policy |

## 6. Target security architecture

### Codebase controls

1. OAuth Authorization Code with PKCE, signed state, OIDC nonce, exact redirect
   allowlist, and validated ID token claims.
2. Session-family model with rotated-token lineage, reuse detection, family-wide
   revocation, device metadata, login history, and short-lived step-up grants.
3. Route-specific distributed throttles backed by Redis plus request/body limits.
4. Security event service with typed events, correlation IDs, redaction, severity,
   and an outbox for reliable SIEM delivery.
5. DNS-safe outbound request service that connects only to the validated resolved
   public address, revalidates redirects, and is backed by network egress policy.
6. Production configuration assertions: no mock mode, HTTPS endpoints only,
   explicit trusted proxies/CORS, Swagger off, secure Redis/MySQL URLs.
7. Expanded ownership, replay, abuse, redaction, and negative authorization tests.

### Cloud/infrastructure controls

- Managed WAF/DDoS protection and API gateway/load balancer TLS termination.
- Private MySQL/Redis networks, TLS, separate runtime/migration/backup identities,
  managed backups, point-in-time recovery, and tested restoration.
- Managed KMS and secret manager with workload identity and rotation.
- Restricted outbound egress; dedicated proxy/resolver for unsubscribe traffic.
- Central immutable logs, SIEM rules, alert routing, and on-call integration.
- Separate development/staging/production accounts, data, keys, OAuth clients,
  networks, and CI identities.

### Third-party services requiring approval/contract

- Cloud KMS/secret manager, managed WAF/DDoS, SIEM/log archive, mobile attestation,
  uptime monitoring, SAST/DAST/container scanners, and an independent penetration
  testing provider.
- Google restricted-scope verification and any required recurring assessment.
- No external AI service should receive raw messages, tokens, secrets, or direct
  identifiers. Approve subprocessors through privacy/security review first.

### Organizational controls

- Security owner, on-call rota, access reviews, incident classification, breach
  decision process, vulnerability disclosure address, vendor review, secure code
  review, key-rotation drills, restore exercises, and independent penetration test.

## 7. Prioritized implementation roadmap

### P0 — production launch blockers

1. Add production-safe configuration assertions and disable Swagger/mock mode in
   production; enforce HTTPS in Flutter release builds.
2. Implement OAuth PKCE/nonce and strict Google identity validation.
3. Add session families, reuse containment, login/device history, revoke-all, and
   security-event generation.
4. Add distributed auth-specific and destructive-route throttles, request-size
   limits, trusted-proxy configuration, and WAF-ready client-IP handling.
5. Add recent-authentication/step-up grants and idempotency for destructive Gmail
   operations. Passkeys can land in P1, but a secure step-up design is required now.
6. Replace direct unsubscribe `fetch` with a DNS-pinned/egress-controlled client.
7. Introduce versioned KMS envelope encryption and a token-key migration plan.
8. Implement structured redacted logging, correlation IDs, security events, and
   launch-critical alerts.
9. Add CI secret/SAST/dependency/SBOM/container/IaC gates and negative auth tests.
10. Deploy private TLS-enabled MySQL/Redis with least-privileged identities;
    validate encrypted backup restoration.
11. Implement account deletion/export, token revocation, and retention jobs.
12. Resolve and document stable Google-sub identity/account-linking rules.

### P1 — before broad rollout

- Passkeys/WebAuthn with TOTP recovery or step-up fallback; recovery codes and
  protected recovery procedures.
- Play Integrity and App Attest/DeviceCheck as risk signals.
- Immediate access-token invalidation for high-risk session events.
- Screenshot/application-switcher/clipboard/cache protections for sensitive views.
- DAST, API fuzzing, mobile MASVS assessment, independent penetration test, and
  incident-response tabletop exercise.
- User-facing login history, remote sign-out, suspicious-login notification, and
  security settings that reflect real enforcement.

### P2 — after sufficient trustworthy telemetry

- Privacy-preserving behavior features and an explainable risk engine.
- Monitor-only anomaly scoring, false-positive measurement, drift monitoring,
  model/version registry, human review, and rollback.
- Progressive actions: observe, notify, rate-limit, require step-up, revoke a
  session family, then manual review. Never permanently block solely on AI output.

## 8. AI-assisted threat detection design

Start with deterministic rules. Emit pseudonymous features such as session ID
hash, coarse geography, ASN/reputation class, device-key hash, login hour bucket,
failure counts, endpoint velocity, authorization failures, refresh reuse, and
bulk-action magnitude. Do not emit raw email text, addresses, tokens, subjects,
or unsubscribe URLs to a model.

Every decision must return a score, stable reason codes, model/rule version, input
feature version, and action. Keep the last known deterministic policy available
when the model or feature pipeline fails. Train only after obtaining consent/legal
review, retention limits, poisoning protections, representative baseline traffic,
and a documented human appeal/review path.

## 9. Monitoring and alert catalogue

| Severity | Event | Initial response |
|---|---|---|
| Critical | Refresh-token reuse, KMS/decrypt anomaly, database public exposure, mass cross-user authorization failure | Revoke family/keys as applicable, page on-call, preserve evidence, begin incident playbook |
| High | OAuth state/nonce/PKCE failures spike, impossible travel plus new device, destructive-action surge, repeated BOLA attempts | Step-up or revoke affected session, rate-limit, notify user/on-call |
| Medium | New device, unusual ASN/country, repeated login failure, queue abuse, unsubscribe SSRF rejection | Enrich, monitor, apply tighter limit, notify if confidence rises |
| Low | Normal login, token rotation, settings change, account connect/disconnect | Retain as redacted audit event |

Required event fields: timestamp, event type/version, severity, correlation ID,
pseudonymous actor/session/device IDs, coarse network context, target type/ID,
outcome, reason codes, rule/model version, and redacted metadata. Never include
authorization headers, tokens, secrets, raw message data, or full email addresses.

## 10. Incident-response playbooks

### OAuth/provider token compromise

Revoke the Google grant; disable affected account sync; revoke SenderWho session
families; rotate wrapping keys only if key compromise is suspected; preserve
redacted evidence; notify affected users; assess Google/privacy notification duties.

### SenderWho account takeover

Revoke the compromised family and optionally all user sessions; require strong
re-authentication; inspect destructive actions and provider changes; notify the
user through a separately verified channel; restore state where provider APIs
permit; tune the rule that detected or missed the event.

### Secret or encryption-key exposure

Disable the credential, rotate it through the managed store, inventory access,
rewrap/re-encrypt affected tokens, redeploy with workload identity, verify no
secret reached logs/builds, and complete notification analysis.

### Database exposure

Isolate network access, rotate DB/application/provider credentials, preserve
snapshots and access logs, establish scope, restore from a verified clean point if
needed, force relevant session revocation, and execute legal/user notification.

### Dependency compromise

Freeze releases, identify affected builds through SBOM/provenance, revoke CI and
signing credentials if necessary, replace/pin the dependency, rebuild in a clean
environment, validate artifacts, and notify users if shipped code was affected.

## 11. Privacy and retention plan requiring product/legal approval

- Define purpose and maximum retention for message metadata, snippets, audit logs,
  security features, IP/device signals, failed OAuth sessions, and job history.
- Default to metadata-only synchronization and avoid persistent full bodies.
- Automatically purge expired OAuth login sessions, revoked/expired app sessions,
  completed job metadata, and data beyond the approved retention period.
- Provide export, account deletion, Gmail disconnect/revocation, consent history,
  and subprocessor disclosure.
- Keep security logs pseudonymous where possible and segregate them from product
  analytics. Document any retention exception needed for fraud investigation.

## 12. Pre-release security checklist

- [ ] All P0 findings closed or explicitly accepted by accountable owners.
- [ ] Production OAuth client verified; exact HTTPS callback and minimum scopes.
- [ ] Mock mode and Swagger fail closed in production.
- [ ] HTTPS-only release client and API; TLS configuration independently tested.
- [ ] KMS/secret manager, key rotation, private DB/Redis, least privilege verified.
- [ ] Route-specific distributed throttling and WAF/DDoS controls tested.
- [ ] Cross-user authorization suite covers every resource and mutation.
- [ ] Step-up and idempotency cover destructive operations.
- [ ] Redaction tests prove tokens, secrets, bodies, and addresses avoid logs.
- [ ] Backups restored successfully in a timed exercise.
- [ ] SAST, secret scan, dependency scan, SBOM, container/IaC scan pass in CI.
- [ ] DAST, API fuzzing, MASVS review, and independent penetration test complete.
- [ ] SIEM alerts reach an owned on-call route; tabletop exercise complete.
- [ ] Privacy notice, retention, export/deletion, subprocessors, and disclosure
      channel approved.

## 13. Penetration-testing scope

- OAuth login transaction, callback, polling secret, account linking, refresh
  rotation/reuse, logout, session revocation, MFA/recovery, and redirect handling.
- BOLA/IDOR across every API, bulk operation, job lookup, account, sender, message,
  content, alert, and settings route.
- Rate-limit bypass, proxy-header spoofing, concurrency/race conditions, replay,
  idempotency, queue flooding, and Gmail quota abuse.
- SSRF including DNS rebinding, redirects, alternate IP encodings, IPv6, metadata
  endpoints, proxy behavior, and egress-policy bypass.
- Injection, mass assignment, error disclosure, CSP/XSS for Flutter web, malicious
  MIME/header/content handling, and deep-link/OAuth callback abuse.
- Android/iOS secure storage, backups, screenshots, application-switcher exposure,
  logs, release configuration, attestation bypass expectations, and binary secrets.
- Cloud IAM, network boundaries, DB/Redis TLS, backups, secret/KMS access, logging,
  CI/CD identities, artifacts, SBOM, and dependency provenance.

## 14. Residual-risk register

| Risk retained after target controls | Why it remains | Owner/action |
|---|---|---|
| Compromised unlocked device can act as the user | Secure storage cannot protect an already-authorized live process completely | Product/security: step-up, device revocation, sensitive-view controls |
| Backend must process Gmail-derived data | Product functionality precludes true E2EE for server-side classification/actions | Privacy/security: minimize, isolate, encrypt, retain briefly |
| Sender-controlled unsubscribe endpoints are inherently hostile | The feature requires outbound requests to third parties | Backend/cloud: pinned resolver client, egress proxy, strict time/size limits |
| Google/service/provider compromise or outage | External dependency is outside SenderWho control | Operations: least scopes, circuit breakers, provider alerts, recovery plan |
| AI false positives/negatives and evasion | Statistical detection is imperfect and adaptive attackers change behavior | Security/ML: monitor-only launch, explainability, drift tests, human review |
| Unknown dependency vulnerabilities | Point-in-time scans cannot detect all future or unpublished issues | Engineering: continuous scans, SBOM, patch SLA, provenance and response plan |

## Verification evidence and limitations

- Source review covered the files listed in the scope above and searched for raw
  Prisma queries, public routes, token handling, outbound fetches, logging, and
  authorization/resource lookups.
- Backend dependency audit: `npm audit --json`, 2026-07-19, zero known findings
  across 762 installed dependencies.
- Existing Flutter analysis/tests and backend unit tests are useful functional
  evidence but do not replace DAST, mobile binary testing, infrastructure review,
  or penetration testing.
- No production cloud account, WAF, KMS, IAM, database, Redis, log platform, CI
  system, Google Console, DNS, certificate, or backup environment was available
  for verification.

## Review gate

Broad security implementation should begin only after the team confirms the
target deployment platform, web-versus-mobile authentication model, MFA/passkey
product behavior, approved KMS/SIEM/WAF vendors, retention periods, and which P0
changes form the first implementation milestone.
