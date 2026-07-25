# SenderWho Production Readiness Audit

Audit date: 2026-07-19  
Decision: **NOT READY**  
Scope: Flutter clients, NestJS API, Prisma/MySQL, Redis/BullMQ, Google OAuth,
Gmail API, security controls, tests, and local deployment configuration.

> Prompt 2 implementation update: use `docs/prompt2_implementation_report.md`
> for the updated traceability matrix, completed P0 application controls, exact
> verification results, residual risks, and Prompt 3 handoff. This file remains
> the original Prompt 1 audit baseline.
>
> Current re-audit: `docs/production_readiness_reaudit.md` supersedes readiness
> conclusions and verification results in this baseline.

This is the assessment-only phase. No broad runtime or database changes were
made, and no real Gmail mutation was executed. The security analysis in
`docs/security_assessment.md` remains authoritative and is incorporated here.

## Status definitions

- **Working:** source path is complete and relevant automated evidence passed.
- **Partial:** meaningful implementation exists, but important behavior or
  production controls are absent.
- **Broken:** implementation exists but a confirmed defect prevents its contract.
- **Mock-only:** useful only with preview/mock data.
- **Disconnected:** a UI/API/schema element has no complete production path.
- **Unverified:** appears implemented but requires external integration, device,
  infrastructure, or destructive testing not performed in this audit.

## Feature traceability matrix

All non-public rows are protected by the global `JwtAuthGuard`. Service ownership
is stated separately because bearer authentication alone is not object-level
authorization. “Scoped” means the public service lookup includes `userId`.

| Feature / visible action | Flutter screen → repository | API → service | Prisma / worker / provider | Authorization | Test evidence | Status |
|---|---|---|---|---|---|---|
| Open onboarding and connect flow | `OnboardingScreen` → navigation | None | None | Public UI | Multi-viewport widget tests | Working |
| Start Google connection | `ConnectEmailScreen` → `startOAuth` | `POST auth/oauth/google/start` → `AuthService.startOAuth` | Creates hashed-secret `OAuthLoginSession`; returns Google authorization URL | Public, general throttle | Repository cancellation test; auth unit test | Partial: signed state and one-time poll secret exist; PKCE/nonce absent |
| Cancel OAuth in Flutter | Connect dialog → `cancelOAuth` | No cancellation endpoint | Local attempt invalidated; server login expires later | Local | Repository test | Working locally; server session is not immediately canceled |
| Google callback | External browser → polling app | `GET auth/oauth/google/callback` → `handleOAuthCallback` | Google token/userinfo/Gmail profile; upserts User/EmailAccount; encrypts tokens; queues scan | Public callback; signed state | Controller HTML escaping tests; partial service tests | Partial/unverified: no live Google test, PKCE/ID-token nonce validation absent |
| Exchange OAuth login | `startOAuth` poll → private `_requestJson` | `POST auth/oauth/session/exchange` | Constant-time secret check; atomically exchanges; creates hashed `AppSession` | Public, possession of high-entropy secret | Auth service tests | Working baseline; auth-specific rate limit absent |
| Restore returning session | App startup → `restoreSession` | `POST auth/refresh` | Finds hashed token; rotates and revokes old row | Public refresh | Flutter repository and auth tests | Partial: no session family or reuse containment |
| Retry API after access expiry | Repository `_requestJson` → `_refreshSession` | `POST auth/refresh`, retry original endpoint | New JWT and refresh token | Token rotation | Flutter repository test | Working baseline; replay/family risk remains |
| Current-device sign out | Drawer confirmation → `logout` | `POST auth/logout` | Revokes matching refresh session | Public with refresh-token possession | Flutter widget and auth unit tests | Working baseline; current access JWT remains valid until expiry |
| Remote sessions / revoke all | No UI/repository method | No endpoint | Schema stores sessions only | None | None | Disconnected |
| MFA/passkeys/recovery | Privacy view only | No endpoint/service | Cosmetic `twoFactorEnabled` field | None | None | Disconnected/misleading if presented as protection |
| Dashboard refresh and navigation | `DashboardScreen` → `getDashboard`, `queueAccountSync` | `GET dashboard`; account sync endpoint | User-scoped aggregate counts; optional scan job | Scoped | Dashboard service test; route/widget tests | Working baseline |
| List connected accounts | `ConnectedAccountsScreen` → `getConnectedAccounts` | `GET email-accounts` → `listForCurrentUser` | `EmailAccount.findMany({userId})` | Scoped | Route rendering only | Working source path; no API integration test |
| Scan/retry connected account | Connected accounts/dashboard → `queueAccountSync` | `POST email-accounts/:id/sync` | Scoped lookup; BullMQ `scan-inbox` | Scoped | Scheduler unit test only | Partial/unverified end-to-end |
| Disconnect Gmail | Confirmation → `disconnectAccount` | `DELETE email-accounts/:id` | Scoped lookup; Google revoke; clears encrypted tokens; audit row | Scoped | Widget route coverage only | Partial/unverified; no step-up/idempotency/integration test |
| Scheduled scans | No direct UI | Internal `InboxScanScheduler` | Finds due accounts; queues `scan-inbox` | Internal worker trust | Scheduler unit tests | Working baseline; no distributed scheduler lock |
| Initial Gmail sync | Connection/scan job | `ScanInboxProcessor` → `GmailSyncService.syncAccount` | Gmail profile/list/metadata; sender/message upsert; suggestions | Internal account ID | No processor/sync service integration test | Partial/unverified |
| Incremental Gmail history sync | Scheduled/manual scan | `GmailSyncService` | Gmail history pagination; delete/update/upsert local records | Internal account ID | No sync integration test | Partial/unverified |
| Token refresh for Gmail | Indirect from all provider actions | `GoogleTokenService` | Decrypt refresh token; Google token endpoint; encrypt replacement | Internal account ID | Unit tests | Working baseline; static key/KMS gap |
| Dashboard security alert cards | Dashboard → `getDashboard` | `GET dashboard` | Reads `SecurityAlert` | Scoped | Dashboard unit test | Disconnected in production because no alert creator exists |
| List/filter security alerts | `SecurityAlertsScreen` → `getSecurityAlerts` | `GET security-alerts` | Scoped `SecurityAlert.findMany` | Scoped | Route rendering only | Disconnected in production; mock data works |
| Open alert details/review sender | List passes `AlertItem`; navigation | `GET security-alerts/:id` exists but Flutter never calls it | Scoped lookup exists | Scoped | Navigation widget coverage only | Partial/disconnected API detail route |
| Resolve alert | Alert details → `resolveSecurityAlert` | `PATCH security-alerts/:id/resolve` | Scoped lookup then update | Scoped | No service/API test | Partial; no audit event or dismiss action |
| Generate fraud/security alerts | No UI action | No detection service | No `securityAlert.create/upsert` in runtime source | None | None | Broken/disconnected; only message `riskFlags` and sender risk values are produced |
| List/paginate/filter email | `EmailsScreen` → `getEmails` | `GET emails` → `EmailMessagesService.list` | Scoped Prisma query, pagination and filters | Scoped | Repository contract; route rendering | Working baseline |
| Open email details | Email list → `getEmail` | `GET emails/:id` | Scoped message lookup | Scoped | Repository contract/widget navigation | Working baseline |
| Load thread | Details → `getEmailThread` | `GET emails/:id/thread` | Scoped anchor and thread query | Scoped | Repository contract | Working baseline |
| Load full message content | Details → `getEmailContent` | `GET emails/:id/content` | Scoped stored lookup; Gmail `format=full` live request | Scoped | Repository contract; service unit test | Partial/unverified with Gmail; sensitive-view controls absent |
| Search/filter | `SearchFilterScreen` → `search` | `POST search`; `GET search/filters` | Scoped sender/message queries | Search scoped; filter catalogue authenticated by global guard | Route rendering only | Working source path; integration/abuse tests absent |
| Archive/unarchive | Emails/details/promotions → `applyEmailAction` | `POST emails/actions/archive|unarchive` | Scoped ID set; Gmail batch modify; local update; audit | Scoped and rejects mixed ownership | Email service and repository tests | Working baseline; no idempotency/step-up |
| Trash/restore | Emails/details/promotions → `applyEmailAction` | `POST emails/actions/trash|restore` | Scoped IDs; Gmail per-message; local update; audit | Scoped | Email service unit tests | Working baseline; external partial failure unverified |
| Mark read/unread | Emails → `applyEmailAction` | `POST emails/actions/read-state` | Scoped IDs; Gmail batch modify; local update; audit | Scoped | Email service unit tests | Working baseline |
| Promotions review | `ReviewPromotionsScreen` → list/archive/trash | `GET emails/promotions` plus action endpoints | Scoped messages and Gmail actions | Scoped | Route rendering only | Working source path; no screen action integration test |
| Sender list/filter/pagination | `AllSendersScreen` → `getSenders` | `GET senders` | Scoped query/count | Scoped | Route/widget coverage | Working baseline |
| Sender details/related mail | `SenderDetailsScreen` → `getSenderDetails`; email navigation | `GET senders/:id`; `GET emails` with sender filter | Scoped sender and messages | Scoped | Navigation widget test | Working baseline; API integration absent |
| Trust/untrust sender | Sender details → `setSenderTrusted` | `PATCH senders/:id/trust` | Scoped lookup; update trusted/block flags | Scoped | No service/API test | Partial |
| Block/unblock sender | Sender details/Block screen → `setSenderBlocked` | `PATCH senders/:id/block` | Scoped lookup; update; future sync detects blocked and trashes via worker | Scoped | Blocked navigation widget test only | Partial/unverified provider effect; no audit/step-up |
| Categories and category navigation | `CategoriesScreen` → `getCategories` | `GET categories` | Scoped category aggregates | Scoped | Route rendering | Working baseline |
| Top senders | `TopSendersScreen` → `getTopSenders` | `GET senders/top` | Scoped aggregate | Scoped | Route rendering | Working baseline |
| Activity insights | `ActivityInsightsScreen` → `getActivityInsights` | `GET activity` | Scoped message aggregates | Scoped | Route rendering | Working baseline |
| Inbox health | `InboxHealthScreen` → `getInboxHealth` | `GET inbox-health` | Scoped message/sender aggregates | Scoped | Route rendering | Working baseline |
| Cleanup suggestions | Bulk/Delete screens → `getCleanupSuggestions` | `GET cleanup/suggestions` | Scoped suggestions | Scoped | Route rendering | Working baseline |
| Create bulk cleanup | Confirmation → `createCleanupJob` | `POST cleanup/jobs` | Scoped account; creates job; queues `cleanup` | Scoped | Cleanup processor unit test | Partial/unverified end-to-end; no step-up/idempotency key |
| Poll cleanup progress | `BulkCleanScreen` → `getCleanupJob` | `GET cleanup/jobs/:id` | Scoped job lookup | Scoped | Route rendering only | Working source path |
| Execute cleanup | Polling UI indirectly | `CleanupProcessor` | Gmail trash; local update; suggestion recalculation | Internal job ID | Processor unit test | Partial: retry can reprocess; restart/race tests absent |
| Find unsubscribe candidates | `UnsubscribeScreen` → `getUnsubscribeCandidates` | `GET unsubscribe/candidates` | Scoped senders/messages | Scoped | Route rendering | Working baseline |
| Confirm/create unsubscribe | Screen → `createUnsubscribeJob` | `POST unsubscribe/jobs` | Scoped sender; job creation; BullMQ queue | Scoped | Processor unit tests | Partial/unverified end-to-end |
| Execute one-click unsubscribe | Job polling → worker | `UnsubscribeProcessor` | HTTPS POST, redirect and IP checks | Internal job ID | SSRF/private-address unit tests | Partial: DNS-rebinding TOCTOU and idempotency limitations |
| Poll unsubscribe job | Screen → `getUnsubscribeJob` | `GET unsubscribe/jobs/:id` | Scoped job lookup | Scoped | Route rendering | Working source path |
| Settings summary/navigation | `SettingsScreen` → `getSettings` | `GET settings` | Scoped counts and `UserSettings` | Scoped | Route/widget coverage | Working baseline |
| Change scan frequency/theme | Settings/drawer → `updatePreferences` | `PATCH settings/preferences` | Scoped settings update | Scoped, strict DTO | Drawer theme test | Working baseline; scheduling behavior lacks integration test |
| Privacy/security summary | `PrivacySecurityScreen` → `getPrivacySecurity` | `GET privacy-security` | Scoped counts/settings/session count | Scoped | Route rendering | Partial/informational only |
| Data retention enforcement | Privacy text displays stored label | No retention mutation/job API | No purge worker | None | None | Disconnected/misleading policy label |
| Export user data | No UI/repository/API | None | None | None | None | Missing |
| Delete SenderWho account | No UI/repository/API | None | Schema cascades exist but unused | None | None | Missing |
| Health endpoint | No primary UI | `GET health` | None | Explicitly public | No direct test | Working source path |
| Microsoft/Yahoo connect | No enabled Flutter option | Public start/callback routes | Service throws `NotImplementedException` | Public | No feature tests | Placeholder/disconnected; should not be advertised |
| IMAP/Microsoft clients | No UI/repository path | No controllers/services invoke them | Placeholder provider clients | None | None | Disconnected |

## Broken, incomplete, and misleading functionality

### Confirmed missing or disconnected

1. Real security alerts are never created. Production scans calculate sender
   risk and message flags, but no runtime code writes `SecurityAlert` records.
2. MFA/passkeys, recovery, session history, remote sign-out, and revoke-all are
   absent. The `twoFactorEnabled` database field has no enforcement path.
3. Data export and SenderWho account deletion have no Flutter or API path.
4. The displayed data-retention value is not enforced by a cleanup job.
5. Alert dismissal is requested in the product brief but only resolve exists.
6. Flutter alert details use list data and do not call the existing alert-detail
   endpoint.
7. Microsoft, Yahoo, and IMAP classes/routes are placeholders without complete UI
   or provider implementation.

### Implemented but not production-complete

1. Google OAuth lacks PKCE and OIDC nonce/ID-token claim verification.
2. Refresh rotation lacks token-family reuse containment and device/session data.
3. Destructive Gmail actions lack recent-auth/step-up and idempotency keys.
4. Unsubscribe URL checking is vulnerable to DNS resolution TOCTOU/rebinding.
5. Flutter has an HTTP default URL without a release-time HTTPS assertion.
6. Rate limiting is a broad in-process/default policy rather than distributed,
   endpoint-, account-, and device-specific protection.
7. Provider-token encryption uses one static environment key without KMS envelope
   encryption or rotation metadata.
8. Swagger is enabled unconditionally; mock mode can bypass production environment
   validation.
9. Logs lack structured correlation, systematic redaction, security-event routing,
   and tamper-resistant storage.
10. Local MySQL and Redis are published on all interfaces; Redis has no password or
    TLS. This is local-only configuration, not a production deployment.

## Risk-ranked security gaps

The complete 22-finding register and standards mapping is in
`docs/security_assessment.md`. Launch priorities confirmed by this audit:

| Rank | Gap | Impact | Priority |
|---|---|---|---|
| 1 | Release client can default to HTTP | Session/data interception | P0 |
| 2 | OAuth PKCE/nonce/ID-token verification absent | Login interception/substitution | P0 |
| 3 | Refresh reuse does not revoke a token family | Persistent account takeover | P0 |
| 4 | No step-up/MFA for destructive Gmail actions | High-impact bearer-token abuse | P0 |
| 5 | No production security-alert generation | Product security promise is not delivered | P0 |
| 6 | Unsubscribe DNS-rebinding/egress gap | Server-side request forgery | P0 |
| 7 | Static token-encryption key, no KMS rotation | Provider-token exposure | P0 |
| 8 | General/local rate limiting only | Brute force, bots, API/queue exhaustion | P0 |
| 9 | No centralized redacted security telemetry | Delayed detection/response | P0 |
| 10 | Unverified DB/Redis/private network/backup controls | Data loss or compromise | P0 |
| 11 | No CI security gates; SBOM generation currently fails | Supply-chain blind spot | P0 |
| 12 | No export/deletion/retention enforcement | Privacy and compliance failure | P0/P1 |

## Missing-test report

### Backend

- No controller/API integration or end-to-end suite.
- No isolated Prisma integration test database or cross-user test matrix for every
  endpoint.
- No `GmailSyncService` initial/incremental/pagination/deletion integration tests.
- No `ScanInboxProcessor` tests.
- No tests for account list/sync/disconnect, sender mutation, cleanup service,
  unsubscribe service, alert service, settings, search, activity, categories, or
  inbox health services.
- No PKCE/nonce tests, auth-specific throttle tests, token-family compromise tests,
  idempotency/replay tests, structured-redaction tests, or production config tests.
- No DNS-rebinding test with a pinned connection; existing URL tests cover private
  address rejection but not the second DNS resolution.
- No worker restart, duplicate delivery, Redis outage, MySQL outage, or load tests.

### Flutter/platform

- No `integration_test` suite or real app-to-local-API end-to-end tests.
- Widget tests confirm route rendering across viewports but do not operate every
  button/form/action or verify success/error/offline/duplicate-submission states.
- No Android/iOS secure-storage integration, deep-link, release HTTPS, screenshot,
  application-switcher, clipboard, web CSP, keyboard-navigation, or desktop tests.
- No approved test-account verification of Google OAuth/Gmail mutations.

### Security/release

- No dedicated secret scanner, SAST, DAST, container/IaC scan, mobile MASVS scan,
  fuzz/property tests, load tests, coverage gate, or penetration test.
- `npm audit` passes, but `npm sbom --sbom-format cyclonedx` fails and must be fixed
  before an SBOM can be retained as release evidence.

## Commands and exact results

| Command | Result |
|---|---|
| `flutter analyze` | PASS: no issues, 2.0 seconds |
| `flutter test` | PASS: 24 tests passed, 1 skipped |
| `npm run lint` | PASS |
| `npm run build` | PASS |
| `npm test -- --runInBand` | PASS: 10 suites, 22 tests |
| `npx prisma validate` | PASS: schema valid |
| `npx prisma migrate status` | PASS when allowed local DB access: 7 migrations, schema up to date |
| `npm audit --json` | PASS: 0 known vulnerabilities across 762 dependencies |
| Targeted secret-pattern filename scan excluding ignored local env files | PASS: no matching files |
| `npm sbom --sbom-format cyclonedx` | FAIL: `EINVALIDPURLTYPE`, invalid `range` package URL for `SenderWho@` |
| `docker compose ps` | MySQL healthy; Redis and Adminer running; DB/Redis published locally |

The targeted secret scan is not equivalent to Gitleaks/TruffleHog and must not be
treated as final release evidence. The first sandboxed Prisma status attempt could
not reach MySQL; the approved read-only retry succeeded.

## Implementation plan

### P0 — before any production release

1. Fail-closed production configuration: HTTPS-only release URL, no production
   mock mode, disable/protect Swagger, explicit CORS/trusted proxies, body limits.
2. OAuth PKCE, nonce, ID-token claim/scope validation, and auth-specific distributed
   rate limits.
3. Session families, reuse containment, device/session history, revoke-current/all,
   and recent-auth/step-up grants.
4. Implement deterministic production security-alert creation, audit events, and
   tested alert lifecycle.
5. Add idempotency/replay controls to destructive operations and fix DNS-pinned
   unsubscribe egress.
6. Introduce versioned KMS envelope encryption and a safe token migration plan.
7. Add correlation IDs, structured redaction, security event outbox/SIEM contract,
   and alert runbooks.
8. Implement export, deletion, provider revocation, retention jobs, and expired
   OAuth/session cleanup.
9. Add API/Prisma integration tests, full cross-user matrix, sync/worker tests, and
   Flutter integration tests.
10. Add CI secret/SAST/dependency/SBOM/container/IaC gates; repair SBOM generation.
11. Supply private TLS MySQL/Redis production configuration, least-privileged
   identities, encrypted backups, and restore evidence.

### P1 — before broad rollout

- Passkeys/WebAuthn or TOTP fallback and secure recovery; user-facing session UI.
- Mobile attestation and sensitive-view protections.
- Immediate access-token invalidation on high-risk events.
- DAST, API fuzzing, MASVS device/binary review, load tests, incident tabletop, and
  independent penetration testing.
- Complete or remove placeholder Microsoft/Yahoo/IMAP surfaces.

### P2 — after trustworthy telemetry exists

- Privacy-preserving, explainable anomaly detection in monitor-only mode.
- False-positive measurement, model/rule versioning, drift monitoring, human
  review, rollback, and progressive risk responses.

## Initial readiness decision

**NOT READY.** The current code is a functional, well-structured development
baseline, and all existing Flutter/backend tests pass. It cannot be called
production-ready because multiple P0 controls and promised functions are missing,
real security alerts are disconnected, external Gmail mutations are unverified,
there is no end-to-end/integration security suite, and production infrastructure
has not been validated.

## Exact Prompt 2 scope

Prompt 2 should implement P0 in five reviewable milestones:

1. **Configuration and transport:** HTTPS fail-closed client/server rules,
   production mock/Swagger restrictions, trusted proxy/CORS/body limits, tests.
2. **Identity and sessions:** PKCE/nonce/ID-token validation, token families,
   reuse containment, device sessions, revoke endpoints/UI, step-up foundation,
   distributed auth throttles, migrations and race/abuse tests.
3. **Destructive-action safety:** idempotency/replay ledger, step-up enforcement,
   DNS-pinned unsubscribe transport, ownership matrix, worker retry/restart tests.
4. **Security/privacy product:** deterministic alert generation and lifecycle,
   structured redacted events/audits, retention/export/deletion/revocation jobs and
   UI, KMS-versioned token encryption abstraction.
5. **Release evidence:** API/Prisma/Flutter integration suites, Gmail test-account
   harness without production data, CI security workflow, repaired SBOM, private
   MySQL/Redis deployment templates, backup/restore and monitoring documentation.

Each milestone must report threat/defect, root cause, files, configuration, tests,
exact results, limitations, and rollback. Prompt 2 must not claim completion for
cloud KMS/WAF/SIEM/penetration testing unless those external systems are actually
configured and verified.
