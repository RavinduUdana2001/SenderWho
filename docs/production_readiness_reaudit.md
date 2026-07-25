# SenderWho Production Readiness Re-audit

> Historical re-audit. The supported single-Hostinger-VPS security plan is now
> documented in `docs/security_architecture.md`. Unimplemented enterprise cloud
> services in this report must not be presented as current product features.

Audit date: 2026-07-19  
Decision: **NOT READY FOR PRODUCTION SIGN-OFF**  
Scope: Flutter clients, NestJS API, Prisma/MySQL, Redis/BullMQ, Google OAuth,
Gmail operations, security controls, local deployment assets, CI configuration,
and the baseline in `docs/security_assessment.md`.

## Implementation update — 2026-07-20

This pass completed additional product, resilience, responsive-UI, privacy, and
ownership work without using production data or performing a destructive Gmail
operation:

- The shared page shell now provides consistent SenderWho light/dark ambience,
  wider tablet/desktop constraints, reading-order keyboard focus, and accessible
  Back/Open-menu tooltips. The dashboard uses a wider responsive content canvas
  while message-focused screens retain a readable centered measure.
- Search now supports bounded server pagination, explicit `hasMore` state,
  client-side page merging without duplicate IDs, load-more progress, inline
  retry errors, exclusive trust/date choices, and direct message-object
  navigation. Every Prisma sender/message search and count remains scoped to the
  authenticated `userId`.
- Privacy export now retrieves every page of profile, account, sender, message,
  alert, and audit data, packages one versioned JSON export, and opens native
  save/share delivery on Android, iOS, web, macOS, and Windows. It does not write
  an unencrypted intermediate file inside the app.
- Email detail actions now reliably return a changed result to the previous list
  for both header and system back navigation. One-click unsubscribe from message
  details now requires an explicit confirmation before creating a job.
- Cleanup job polling preserves active jobs across transient API failures,
  exposes a retry state, and no longer silently drops progress tracking.
- Summary/filter screens now show genuine loading states instead of temporary
  zero/default content. A fast nested session error is handled until its visible
  retry UI is mounted.
- Added regression tests for complete export paging/delivery, search paging and
  page merging, message-action return navigation, and authenticated-user
  ownership across search, sender reads/controls, email-account sync/disconnect,
  cleanup jobs, unsubscribe jobs, messages, alerts, and export records.

Latest evidence on 2026-07-20:

- `dart format --output=none --set-exit-if-changed lib test`: pass.
- `flutter analyze`: no issues.
- `flutter test`: 35 passed, 1 intentional preview-only skip.
- Production web release build: pass.
- Production Android release APK: pass.
- iOS Simulator build: pass.
- Backend Prettier check, ESLint, TypeScript build: pass.
- Backend Jest: 20 suites, 59 tests passed.
- Prisma schema validation: pass; all 11 migrations are applied to the local
  MySQL test database.
- Offline high-severity npm audit: 0 vulnerabilities.
- Local SenderWho MySQL, Redis, and Adminer bindings are restricted to
  `127.0.0.1`; MySQL and Redis health checks pass.
- macOS release packaging remains blocked by the missing client-owned Apple
  development signing certificate. Windows requires a Windows-native build
  runner. Native application IDs still use `com.example` pending the
  client-approved reverse-DNS identifier.

Production sign-off remains blocked by approved live Google OAuth/Gmail tests,
full HTTP-level API/MySQL/Redis/BullMQ cross-user E2E coverage, client signing
and identifiers, native Windows validation, and an independent penetration test.
The new service-level ownership tests materially improve local evidence but do
not replace those release gates.

## Implementation update — 2026-07-19

The following items from the audit baseline below were repaired during the
production UI/branding pass. This section supersedes older row-level wording
where the two conflict:

- Applied the supplied SenderWho cyan/blue/violet identity to accessible light
  and dark Material themes, global page ambience, primary actions, in-app icon,
  responsive wordmark, and drawer tagline. Existing Android, iOS, macOS, web,
  and Windows launcher artwork uses the supplied icon-only asset.
- Alert details now refresh through `GET security-alerts/:id`, return the same
  safe public DTO shape as the list endpoint, support resolve and dismiss,
  prevent duplicate submission, and implement dismiss in mock mode.
- Added the missing security-notification preference control and retained
  system/light/dark theme persistence.
- Gmail disconnect now preserves and displays `providerRevoked` instead of
  claiming that Google access was always revoked. The drawer describes the
  authenticated SenderWho session rather than falsely claiming Gmail is linked.
- Added a duplicate-submit lock to the dedicated block-sender confirmation.
- Required read paths now distinguish API/transport failure from genuinely
  empty data. Alerts, accounts, settings, categories, health, activity, top
  senders, cleanup, promotions, unsubscribe, search, privacy, and session views
  provide explicit retry states.
- Fixed the Android debug manifest merge while keeping the production manifest
  HTTPS-only. Fixed the CI formatting gate by separating TypeScript Prettier
  checking from Prisma schema validation.
- Added regression coverage for user-scoped alert serialization, preview alert
  dismissal, alert detail/dismiss idempotency, disconnect revocation metadata,
  required-read failures, alert actions, and notification controls.

Latest local evidence after these changes:

- Flutter analysis: no issues; Flutter tests: 30 passed, 1 intentional preview
  skip; web release build passed; Android debug and release APK builds passed;
  iOS Simulator build passed.
- Backend ESLint, TypeScript build, Prettier check, Prisma validation, and all 49
  Jest tests passed.
- macOS compilation still requires an Apple development signing certificate.
  Windows requires a Windows-native CI/runner. All native identifiers still use
  `com.example` and must be replaced with the client-approved reverse-DNS ID
  before OAuth/App Store configuration; guessing that identity would break
  signing and Google OAuth registration.

Production sign-off remains blocked by live Google/Gmail end-to-end validation,
real MySQL/Redis/BullMQ API integration and BOLA testing, client-owned signing
and package identities, complete save/share UX for all paginated export data,
cloud/SIEM/KMS/backup evidence, and an independent penetration test.

This is an assessment pass over the current repository after the earlier P0
implementation. No application/runtime behavior was broadly changed. No
production data, real Google token, or destructive Gmail action was used.

## Status definitions

- **Working:** the current source path is connected and relevant local automated
  evidence passed.
- **Partial:** a meaningful path exists, but behavior, resilience, security, or
  product handling is incomplete.
- **Broken:** a confirmed defect prevents the stated contract.
- **Mock-only:** the path is only usable in debug preview/mock mode.
- **Disconnected:** one layer exists but no complete caller-to-result path exists.
- **Unverified:** the source path appears complete but requires a real provider,
  device, runner, cloud service, or security assessment not used in this audit.

`Working` below does not mean independently penetration-tested or production
approved.

## 1. UI-to-data traceability matrix

The global `JwtAuthGuard` protects every route except health and the explicitly
public OAuth/session endpoints. “Scoped” means the service lookup includes the
authenticated `userId`. The test column distinguishes rendering/unit evidence
from a real API or Gmail integration test.

| Screen and every user action | Flutter repository path | API and service | Prisma / queue / Google path | Authorization and test evidence | Status |
|---|---|---|---|---|---|
| App bootstrap: restore session; load saved theme | `restoreSession`, `getSettings` | `POST auth/refresh`, `GET settings` | `AppSession` atomic rotation; `UserSettings` read | Refresh is public but requires a high-entropy token; repository/auth tests | **Working locally** |
| Onboarding: **Connect my inbox** | Navigation only | None until connect screen | None | Multi-viewport widget tests | **Working** |
| Connect Email: back, Google connect, cancel, retry | `startOAuth('google')`, `cancelOAuth` | `POST auth/oauth/google/start`; callback; session exchange | `OAuthLoginSession`; PKCE verifier encryption; nonce/state; Google token, ID-token and Gmail profile checks; initial `scan-inbox` enqueue | Start/callback/exchange throttled; auth/controller/repository tests | **Unverified** with live Google; cancel is local only and leaves the server login row to expire |
| Dashboard: drawer, refresh, search, health, metrics, sender cards, alert cards, view-all links, bulk clean, unsubscribe, scan Gmail | `getDashboard`, `queueAccountSync` plus navigation | `GET dashboard`; `POST email-accounts/:id/sync` | Scoped aggregates; `EmailAccount`; BullMQ scan job | JWT + scoped account; dashboard unit and viewport/navigation tests | **Partial/unverified**: scan/Gmail and several failure states lack integration tests |
| Drawer: 11 navigation items, close, dark-mode switch, sign-out/cancel | Navigation, `updatePreferences`, `logout` | `PATCH settings/preferences`; `POST auth/logout` | `UserSettings`; revoke matching `AppSession` | Preference is authenticated/idempotent; logout token possession; widget tests | **Partial**: navigation/sign-out/theme work locally, but “Connected” can be shown after the only Gmail account is disconnected |
| Connected Accounts: refresh, scan now/retry, reconnect, disconnect/cancel | `getConnectedAccounts`, `queueAccountSync`, `startOAuth`, `disconnectAccount` | `GET/POST/DELETE email-accounts` | Scoped `EmailAccount`; scan queue; best-effort Google token revocation; encrypted tokens cleared; audit | Sync idempotent/throttled; disconnect recent-auth/idempotent/throttled; no API E2E | **Unverified**; UI does not distinguish an API failure from an empty account list and does not surface provider-revocation failure |
| All Senders: refresh, search submit, risk/control filters, sender open, load more | `getSenders`, `getSenderDetails` after navigation | `GET senders`, `GET senders/:id` | Scoped sender query/count and related messages | Scoped; only route/navigation evidence | **Partial**: connected source path, no API integration/error-state coverage |
| Sender Details: retry, trust/untrust, block/unblock with confirmation, filter related mail, open all/open message | `getSenderDetails`, `setSenderTrusted`, `setSenderBlocked` | `GET senders/:id`; `PATCH .../trust|block`; `GET emails` after navigation | Scoped `Sender` update; audit; later sync trashes new mail from blocked senders | Mutations recent-auth/idempotent/throttled; no service/API tests | **Partial/unverified** |
| Block Sender confirmation screen: back, **Block Sender** | `setSenderBlocked` | `PATCH senders/:id/block` | Scoped `Sender` update and audit | Recent-auth/idempotent/throttled | **Partial**: no busy lock on this screen and no API regression test |
| Categories: open each category | `getCategories`; navigation to email list | `GET categories`, then `GET emails` | Scoped `Message.groupBy` and filtered message query | JWT/scoped query; viewport test only | **Partial**: load failures collapse to an empty list with no retry |
| Top Senders: open sender; **View All Senders** | `getTopSenders` | `GET senders/top` | Scoped sender aggregate | JWT/scoped query; viewport test only | **Partial**: no API/error-state test |
| Activity Insights: view totals and weekly chart | `getActivityInsights` | `GET activity` | Scoped message/cleanup aggregates | JWT/scoped queries; viewport test only | **Partial**: read-only path exists; errors are displayed as “Unavailable” without retry |
| Inbox Health: back; view health metrics | `getInboxHealth` | `GET inbox-health` | Scoped message/sender counts | JWT/scoped queries; viewport test only | **Partial**: no API/error-state test |
| Email Inbox: search submit, category picker, mailbox tabs, clear filter, refresh, select one/all, open message, load more | `getEmails`, `getCategories`, `getEmailThread` after navigation | `GET emails`, `GET categories`, `GET emails/:id/thread` | Scoped paginated `Message`/`Sender` queries | JWT/scoped; repository contract and widget navigation tests | **Working source path; unverified API E2E** |
| Email Inbox bulk bar: mark read, mark unread, archive/unarchive, trash/restore with confirmation | `setEmailsRead`, `archiveEmails`, `unarchiveEmails`, `trashEmails`, `restoreEmails` | Five `POST emails/actions/*` routes | Preflight scoped ID set rejects mixed ownership; Gmail batch modify/trash/untrash; scoped local update; audit | Idempotent and route throttles; trash recent-auth; email service and repository tests | **Unverified with Gmail**; partial-failure handling exists but is not provider-tested |
| Email Details: retry metadata/content, select thread item, sender profile, archive/unarchive, read/unread, trash/restore, unsubscribe | `getEmail`, `getEmailThread`, `getEmailContent`, `applyEmailAction`, `createUnsubscribeJob` | Message detail/thread/content/action routes; unsubscribe job route | Scoped message lookup; live Gmail `format=full`; HTML converted to plain text; provider actions; audit/queue | Scoped; destructive routes step-up/idempotent; content and action unit contracts | **Partial/unverified**; there is no compose/draft/content-edit function |
| Promotions Review: select one/all, open message, cancel/confirm archive or trash | `getPromotionEmails`, `archiveEmails`, `trashEmails` | `GET emails/promotions`; action routes | Scoped messages; Gmail mutations; local state and audit | JWT/scoped; route rendering only | **Unverified with Gmail** |
| Search & Filter: text form submit, category/trust/date chips, attachment/unread switches, search button, open sender/message | `getSearchFilterOptions`, `search` | `GET search/filters`, `POST search` | Scoped `Sender`/`Message` queries | Search throttled; no service/API tests | **Partial**: first result page only; options-load failure has no retry/error differentiation |
| Bulk Clean: select groups, review, cancel/confirm, create and poll jobs | `getCleanupSuggestions`, `createCleanupJob`, `getCleanupJob` | `GET cleanup/suggestions`; `POST/GET cleanup/jobs` | Scoped account/job; BullMQ cleanup; Gmail trash; progress/failure counts; audit | Create recent-auth/idempotent/throttled; processor retry tests | **Unverified end-to-end** |
| Delete Emails: retry suggestions, cancel/confirm, move suspicious groups to Trash | `getCleanupSuggestions`, `createCleanupJob` | Cleanup routes | Same cleanup queue/Gmail path | Same controls | **Partial/unverified**: repository converts API failure to an empty list, so the screen's `snapshot.hasError` retry branch is normally unreachable |
| Unsubscribe: refresh, one sender, all senders, cancel/confirm, job polling | `getUnsubscribeCandidates`, `createUnsubscribeJob`, `getUnsubscribeJob` | `GET candidates`; `POST/GET jobs` | Scoped sender/job; BullMQ; DNS-pinned public HTTPS POST; redirects revalidated; audit | Create recent-auth/idempotent/throttled; worker retry/SSRF unit tests | **Unverified externally**; no egress-policy or hostile-endpoint integration test |
| Security Alerts: All/High/Medium tabs; open an alert; reload after change | `getSecurityAlerts` | `GET security-alerts` | Scoped `SecurityAlert` read; high-risk alerts are upserted during Gmail sync | JWT/scoped; no alert service/sync integration test | **Partial/unverified**: detection is a small deterministic Gmail/domain rule, not an AI anomaly engine; failures can appear as an empty list |
| Alert Details: sender profile, review related mail, block, resolve | passed `AlertItem`; `resolveSecurityAlert` | `PATCH security-alerts/:id/resolve`; detail endpoint exists | Scoped alert update and audit | Resolve recent-auth/idempotent; no API test | **Partial/disconnected**: Flutter does not call `GET security-alerts/:id`; dismiss API/repository exists but no dismiss control; resolve has no local busy lock |
| Settings: connected/manage accounts, privacy, categories, scan-frequency choices, theme choices, archived/trash/blocked navigation | `getSettings`, `updatePreferences` | `GET settings`; `PATCH settings/preferences` | Scoped counts and `UserSettings` upsert/update; audit | JWT; preference update idempotent; drawer theme widget test | **Partial**: notifications preference exists in DTO/model but has no settings control; load errors silently use defaults |
| Privacy & Security sessions: sign out one/current/all, cancel, blocked/trusted navigation | `getPrivacySecurity`, `getSessions`, `revokeSession`, `revokeAllSessions` | `GET privacy-security`; session list/revoke routes | Scoped counts; backing `AppSession` is checked on every request; security audit | Revoke recent-auth/idempotent; guard/auth tests | **Working locally; API E2E unverified** |
| Privacy export: **Prepare data export** | `exportData` defaults to `profile` | `GET users/me/export` | Scoped paginated profile/accounts/senders/messages/alerts/audit reads; audit | Recent-auth and throttle | **Partial/disconnected UX**: UI only fetches the profile page, saves/downloads nothing, and says to use the API |
| Privacy deletion: cancel/confirm **Delete permanently** | `deleteAccount` | `DELETE users/me` | Best-effort Google revoke, cascade delete user data, delete audit data, clear local session | Recent-auth and strict throttle; one service test | **Partial/unverified**: real revocation/deletion not tested; revocation failure is not shown to the user; endpoint has no idempotency ledger |
| Microsoft/Yahoo/IMAP | No enabled UI | No enabled public routes; placeholder provider clients/config remain | Placeholder methods only | None | **Disconnected/disabled** |

## 2. API, Prisma, queue, provider, and test trace

| Endpoint group | Service and ownership | Data/provider side effects | Automated evidence | Status |
|---|---|---|---|---|
| `health` | Public controller | None | Build only | **Working source; deployment probe unverified** |
| `auth/oauth/google/start`, callback, exchange, reauth | `AuthService`; signed state tied to one login row | OAuth session create/claim; Google PKCE/token/ID token/Gmail profile; account upsert; queue | Auth/controller tests cover URL, invalid state, escaping, exchange behavior indirectly | **Unverified live** |
| `auth/refresh`, `logout`, `me`, sessions | `AuthService`; session/user scoping | Refresh family lineage/rotation/reuse revoke; session/device metadata; audit | Auth and JWT guard tests | **Working locally** |
| `dashboard`, `activity`, `categories`, `inbox-health`, `settings`, `privacy-security` | Services scope aggregate queries by `userId` | Read-only aggregates/settings mutation | Dashboard/config only; most services have no direct test | **Partial** |
| `email-accounts` | Every ID lookup includes `userId` | Account reads, queue, Google revoke, token clearing, audit | No controller/service test | **Unverified** |
| `emails` | Every item/thread/content/bulk lookup scopes `userId`; mixed-owner set fails before Gmail | Message read/update, Gmail content and mutations, audit, recalculation | Strongest feature unit suite, but no HTTP/DB/Gmail integration | **Working locally; unverified provider** |
| `senders` | Every sender lookup includes `userId` | Sender control update and audit | No service/API test | **Partial** |
| `cleanup` | Account/job reads include `userId` | CleanupJob, BullMQ, Gmail trash, local update, audit | Processor retry-state tests only | **Unverified** |
| `unsubscribe` | Sender/job reads include `userId` | UnsubscribeJob, BullMQ, pinned HTTPS request, audit | Retry and reserved-address tests | **Unverified externally** |
| `security-alerts` | Every alert lookup includes `userId` | Alert lifecycle and audit; Gmail sync creates high-risk alerts | No alert/sync test | **Partial** |
| `users/me/export`, `DELETE users/me` | User comes only from JWT principal | Scoped export; revoke attempt; cascade deletion | One deletion unit test | **Partial/unverified** |

Prisma contains 13 principal models: `User`, `IdempotencyRecord`, `AppSession`,
`OAuthLoginSession`, `UserSettings`, `EmailAccount`, `Sender`, `Message`,
`SecurityAlert`, `CleanupSuggestion`, `CleanupJob`, `UnsubscribeJob`, and
`AuditLog` (plus enums). Runtime source uses Prisma's typed API; no raw SQL call
was found. Eleven migrations applied cleanly to a disposable empty MySQL schema.

Queues are `scan-inbox`, `cleanup`, and `unsubscribe`. Scan jobs deduplicate by
account and retry four times; cleanup and unsubscribe jobs use fixed job IDs and
retry three times. Scheduled scanning and retention run as in-process timers,
not as a leader-elected/managed singleton.

## 3. Broken, incomplete, disconnected, and unverified work

### Confirmed broken

1. The checked-in backend CI formatting command includes `prisma/schema.prisma`
   in a Prettier invocation. Current Prettier has no Prisma parser, so that CI
   step exits 2 before later security gates run.
2. The macOS release build fails because the Runner entitlements require a
   signing certificate but development/release signing is not configured for
   this environment.
3. The currently running local MySQL database is four security migrations
   behind the source schema. The migration files themselves are valid; all 11
   passed on a disposable empty database.

### Incomplete or disconnected product behavior

1. No app-level passkey, WebAuthn, TOTP, recovery-code, or MFA enrollment flow
   exists. Google reauthentication provides recent-auth step-up, but is not an
   app-managed MFA architecture.
2. Alert detail is list-data only; the detail endpoint is unused. Alert dismissal
   is API/repository-only and has no UI action.
3. Export fetches only the profile section and does not assemble, save, share, or
   download an export across any supported platform.
4. Notification preference exists in the backend/model but not in Settings.
5. “Email edit” as compose/draft/body editing is absent. The implemented edits
   are read/unread, archive/unarchive, trash/restore, and sender controls.
6. Several list/summary repositories return empty/default values on transport
   failure. Corresponding screens can present false empty/zero states instead of
   a distinct error/offline/retry state.
7. Google revocation is best effort during disconnect/account deletion, while the
   Flutter UI reports generic success and discards `providerRevoked`/revocation
   counts.
8. OAuth cancel invalidates only the local attempt; the server login row remains
   pending until expiry.
9. Microsoft, Yahoo, and IMAP configuration/client placeholders remain disabled
   and disconnected.

### Unverified production behavior

1. No approved Google test account was used for connect, reconnect, token refresh,
   initial/history sync, every Gmail mutation, partial failure, disconnect, or
   revocation.
2. No API E2E suite exercises real Nest middleware/guards/interceptors, MySQL,
   Redis, BullMQ, or a cross-user BOLA matrix for every ID route.
3. Production edge TLS, WAF/DDoS, private MySQL/Redis TLS, least privilege,
   backups/restore, KMS, secret manager, immutable SIEM, paging, and egress policy
   were not available.
4. Windows was not buildable on macOS. Web, Android, and unsigned iOS release
   builds passed; macOS signing failed.
5. CodeQL, Gitleaks, Trivy, container scanning, DAST, API fuzzing, MASVS review,
   and penetration testing were not run locally. Their CI workflow is present but
   has not been observed, and is currently blocked by the formatting defect.

## 4. Security audit and ranked gaps

| Rank | Current finding | Risk | Priority |
|---:|---|---|---|
| 1 | No staging/live end-to-end proof for OAuth, Gmail, queues, every mutation, and every cross-user object path | Account/data corruption or authorization defects may survive unit tests | **P0** |
| 2 | CI security gates are effectively blocked by the failing Prisma/Prettier command; generated SBOM is not retained by CI | Unsafe changes can merge without working release gates/evidence | **P0** |
| 3 | Managed KMS/workload identity, private TLS DB/Redis, WAF, immutable SIEM/paging, backups/restore, and cloud egress controls are designs rather than verified deployments | Token/data compromise may be undetected or unrecoverable | **P0** |
| 4 | App-level MFA/passkeys and protected recovery are absent despite the stated product requirement | Stolen Google/app sessions have fewer independent defenses | **P0/P1** |
| 5 | Real Google consent configuration, restricted-scope approval, exact production redirect, and revoke behavior are unverified | Login/provider access can fail or violate launch requirements | **P0** |
| 6 | Export UX is incomplete and provider revocation failures are hidden | Privacy requests can appear complete when they are not | **P0/P1** |
| 7 | macOS signing is broken and Windows has no native build evidence | Multi-platform release promise is incomplete | **P0** for those launch platforms |
| 8 | Security alerts use limited deterministic Gmail/category/domain rules; no account-login anomaly pipeline, AI governance, drift/false-positive monitoring, or human-review workflow exists | The requested AI threat-detection promise is not implemented | **P1/P2** |
| 9 | JWTs do not set/verify an application issuer or audience; safe operation currently depends on a unique secret never being shared | Cross-service token confusion if key management is weak | **P1** |
| 10 | Web CSP permits any HTTPS connection and inline style/script requirements; no deployment-header/browser test exists | Web compromise/exfiltration defenses are not release-proven | **P1** |
| 11 | In-process scheduler/retention timers have no distributed leader lock and retention does not run immediately at startup | Duplicate work or retention never running during frequent restarts | **P1** |
| 12 | Current local Docker containers still expose MySQL/Redis on `0.0.0.0`, despite the checked-in compose now binding to localhost | Nearby/local network access to development services | **P1/local remediation** |
| 13 | Sensitive screen snapshot/clipboard/cache controls, mobile attestation, and device compromise signals are absent | Data exposure on compromised or unattended devices | **P1** |

### Common-attack control result

| Threat | Result |
|---|---|
| SQL injection | **Working source control:** Prisma typed API and no raw SQL found; no dynamic scanner/fuzzer was run |
| IDOR/BOLA | **Partial:** reviewed services scope by `userId`, and one mixed-owner email test passes; comprehensive cross-user HTTP tests are missing |
| XSS | **Partial/strong baseline:** OAuth HTML is escaped; email HTML becomes plain text; Flutter renders text. Flutter-web deployment CSP/DAST remains unverified |
| CSRF | **Low current exposure:** bearer headers are used instead of auth cookies. Reassess if cookie authentication is introduced |
| SSRF | **Working source control, unverified defense-in-depth:** unsubscribe uses public-HTTPS checks, DNS pinning, TLS hostname validation, redirect revalidation, timeout, and reserved-address blocks; cloud egress and hostile DNS tests remain |
| Replay/double submit | **Partial:** decorated mutations require a scoped idempotency key and Flutter preserves it across auth retries; rapid independent taps create different keys and a few screens lack busy locks; account deletion is not decorated |
| Brute force/bots | **Partial:** Redis-backed route-specific limits exist; WAF, device/account reputation, queue quotas, load/bypass tests, and anomaly detection are absent |
| Transport/CORS/headers | **Working source, unverified edge:** release HTTPS assertion, Android cleartext block, Apple ATS, production HTTPS middleware, exact CORS validation, Helmet/CSP, no-store, trusted proxies, and body limits exist |
| Secrets/encryption | **Partial:** provider tokens use versioned AES-256-GCM with record context; managed KMS/envelope encryption and rotation exercise are absent. Gmail data processed by the server cannot truthfully be called end-to-end encrypted |
| Logging/alerting | **Partial:** correlation IDs, structured header/body-free logs and audit rows exist; there is no verified immutable sink, reliable outbox, SIEM paging, or redaction test suite |

## 5. P0/P1/P2 implementation plan

### P0 — before production or any promised launch platform

1. Fix the CI formatting gate, add and retain CycloneDX SBOM/provenance, and
   require successful backend, Flutter, CodeQL, Gitleaks, Trivy, container, and
   IaC jobs before merge/release.
2. Build a disposable MySQL/Redis/BullMQ API E2E harness. Cover every endpoint,
   all DTO failures, unauthenticated access, one user attempting every other
   user's ID, idempotency races, refresh reuse, step-up, queue duplicates/restarts,
   and Redis/MySQL/provider outages.
3. Use an approved Google test tenant/account to test the complete OAuth/Gmail
   lifecycle and all provider mutations, including partial failures and revoke.
4. Complete production cloud controls: KMS adapter/workload identity, secret
   manager, private verified-TLS MySQL/Redis, WAF/DDoS, strict egress, encrypted
   backups with restore evidence, immutable SIEM/paging, and least-privilege
   runtime/migration identities.
5. Implement the agreed app MFA/passkey and recovery design, or obtain a written
   product/security decision defining Google MFA plus Google step-up as the launch
   control and accurately describe it in the UI/privacy documentation.
6. Complete export download/save/share with all paginated sections; surface and
   remediate Google revoke failures; test irreversible deletion end-to-end.
7. Configure macOS signing and add Windows-native CI release builds if those
   platforms are in the launch scope. Install and smoke-test all artifacts.
8. Apply the four security migrations to each non-production environment through
   the migration identity, then rehearse production deploy/rollback/restore.

### P1 — before broad rollout

- Add alert detail fetching/dismiss UI, notification settings, explicit
  offline/error/retry states, busy locks, and action-level widget/integration tests.
- Add JWT issuer/audience validation, security-notification delivery, mobile
  attestation as a risk signal, sensitive-screen snapshot/cache/clipboard controls,
  and narrow deployment CSP/connect destinations.
- Replace process timers with a managed singleton scheduler or distributed lock.
- Add DAST, API fuzz/property testing, queue/load/chaos tests, mobile MASVS review,
  incident tabletop, key rotation, and backup restore exercises.
- Recreate the local Docker stack so the current localhost-only port bindings take
  effect; never use the development compose file for production data.

### P2 — after trustworthy privacy-reviewed telemetry exists

- Add an explainable anomaly engine using pseudonymous device/session/network and
  velocity features, not raw email content or identifiers.
- Start monitor-only; record stable reason codes, rule/model version, false
  positives, drift, overrides, and rollback. Progress from notify/rate-limit to
  step-up/session revocation; never permanently block solely on AI output.

## 6. Missing-test report

Backend coverage is 47.78% of lines and 30.01% of branches. Flutter coverage is
48.13% of lines. Passing route-render tests are not action or backend integration
tests.

Missing or inadequate evidence includes:

- Nest HTTP E2E and real Prisma integration for every controller.
- Full cross-user BOLA matrix for accounts, messages/content/thread/bulk actions,
  senders, alerts, cleanup jobs, unsubscribe jobs, sessions, export, and deletion.
- OAuth PKCE/nonce/claim negative matrix against Google-style tokens and live
  callback/reconnect behavior.
- Gmail initial/history pagination, deleted-message reconciliation, alert creation,
  blocked-sender provider effects, quota/429, 401 refresh races, and partial batch
  failure integration tests.
- `ScanInboxProcessor`, account service, sender service, alert service, cleanup
  service, unsubscribe service, settings, search, categories, activity, inbox
  health, privacy summary, retention, logging/redaction, and Redis throttle tests.
- Browser CSP/XSS/CSRF validation, API DAST/fuzzing, SSRF hostile-DNS/egress tests,
  and load/rate-limit bypass tests.
- Flutter integration tests that tap every action and verify loading, success,
  empty, error, retry, offline, cancellation, duplicate submission, step-up, and
  partial failure.
- Android/iOS/macOS/Windows secure-storage and installed-release testing, mobile
  screenshots/snapshots/cache/clipboard tests, and accessibility keyboard/screen
  reader testing.
- Independent cloud review, vulnerability scans in the actual CI host, container
  scan, mobile binary assessment, and penetration test.

## 7. Commands and exact results

| Command | Exact result |
|---|---|
| `npx prettier --check "src/**/*.ts" prisma/schema.prisma` | **FAIL (exit 2):** no parser inferred for `prisma/schema.prisma`; this is the current CI command |
| `npx prettier --check "src/**/*.ts"` | **PASS:** all TypeScript matched files use Prettier style |
| `npm run lint` | **PASS** |
| `npm run build` | **PASS** |
| `npm test -- --runInBand` | **PASS:** 14/14 suites, 47/47 tests |
| `npm test -- --runInBand --coverage --coverageReporters=text-summary` | **PASS:** statements 47.51%, branches 30.01%, functions 41.74%, lines 47.78% |
| `npx prisma validate` | **PASS:** schema valid |
| `npx prisma generate` | **PASS:** Prisma Client 6.19.3 generated |
| `npx prisma migrate status` against normal local DB | **NOT UP TO DATE:** 11 found; four `20260719*` security migrations unapplied |
| Disposable `npx prisma migrate deploy` | **PASS:** all 11 migrations applied to empty `senderwho_audit_20260719` |
| Disposable `npx prisma migrate status` | **PASS:** database schema up to date; disposable database then removed |
| `dart format --output=none --set-exit-if-changed lib test` | **PASS:** 45 files, 0 changed |
| `flutter analyze` | **PASS:** no issues |
| `flutter test` | **PASS:** 25 passed, 1 intentional preview skip |
| `flutter test --coverage` | **PASS:** 2,473/5,138 lines, 48.13% |
| Flutter web release build with HTTPS API define | **PASS:** `build/web` |
| Flutter Android APK release build with HTTPS API define | **PASS:** 53.3 MB APK |
| Flutter iOS release build, `--no-codesign`, HTTPS API define | **PASS:** 19.1 MB `Runner.app` |
| Flutter macOS release build | **FAIL:** entitlements require a development signing certificate |
| Flutter Windows release build | **UNAVAILABLE:** Windows builds require a Windows host |
| `npm audit --audit-level=high` | **PASS:** 0 known vulnerabilities |
| `npm sbom --sbom-format cyclonedx` | **PASS:** CycloneDX 1.5 JSON generated to stdout |
| `npm outdated` | Patch updates available; major upgrades include Prisma 7, Jest 30, ESLint 10, and TypeScript 7; not vulnerability findings |
| `flutter pub outdated` | Direct/dev dependencies up to date; newer incompatible transitive releases listed |
| Targeted credential-literal scan excluding local env/build/vendor files | **PASS:** no recognized private-key/API-token literal; not a substitute for Gitleaks |
| Platform syntax checks | **PASS:** Android manifests, Apple plists/entitlements, compose YAML, and workflow YAML parse |
| `docker compose ps` | MySQL/Redis/Adminer running; existing MySQL and Redis containers are published on `0.0.0.0`/IPv6 despite current compose localhost bindings |
| Production compose config | **BLOCKED/expected configuration:** `server/.env.production` and required image tag are deployment inputs and are absent locally |
| `docker build --check` | **BLOCKED:** Docker Hub metadata resolution timed out |
| Local Gitleaks/Trivy/Semgrep/Syft availability | **UNAVAILABLE:** binaries not installed |
| `git status --short` | **UNAVAILABLE:** workspace has no `.git` repository, so tracked-secret and change-provenance checks cannot be performed |

The SBOM command's very large JSON was inspected only for successful generation
and was not committed. Local `.env` files were identified by filename only and
their contents were not used or exposed in this report.

## 8. Initial readiness decision

**NOT READY FOR PRODUCTION SIGN-OFF.**

The current source is no longer the insecure prototype described by the original
assessment: the most important application-layer P0 designs are present, all
existing tests pass, dependency audit is clean, migrations apply to an empty
database, and three release targets build. However, SenderWho still cannot claim
that every function works securely in production. Live Google/Gmail, complete
HTTP/BOLA and failure-path testing, app MFA, managed KMS/cloud/SIEM controls,
privacy completion, working CI gates, signed macOS, Windows evidence, DAST/mobile
review, and penetration testing are required before approval.

## 9. Exact work for Prompt 2

Prompt 2 should be a focused remediation and staging-evidence pass:

1. Repair CI formatting and add retained SBOM/provenance; make every security job
   mandatory and demonstrate one full green run.
2. Add disposable MySQL/Redis/BullMQ Nest E2E infrastructure and a table-driven
   unauthenticated/cross-user/idempotency/step-up test for every endpoint.
3. Add Gmail/OAuth adapters or fixtures for deterministic integration tests, then
   run the complete real flow only with an approved Google test account.
4. Finish alert detail/dismiss, notifications, full paginated export download,
   revoke-failure UX, distinct error/offline/retry states, and double-submit locks.
5. Decide and implement passkeys/TOTP/recovery or document and approve the exact
   Google-MFA plus step-up launch boundary; do not label cosmetic settings as MFA.
6. Integrate managed KMS and staging cloud controls, verify MySQL/Redis TLS and
   least privilege, restore backups, deliver SIEM pages, and enforce egress/WAF.
7. Configure macOS signing and Windows CI, build/install every platform artifact,
   and execute secure-storage/transport/sensitive-view tests.
8. Run SAST, secret, dependency, container, IaC, DAST, API fuzz, load, MASVS, and
   independent penetration tests; resolve or formally accept every high/critical
   finding.
9. Update this matrix with evidence links and issue the final evidence-based
   production go/no-go decision.
