# SenderWho CASA failed-controls review — 23 October 2026

This is an initial verification and action plan, not a compliance certificate or completed reassessment. No application code, production settings, DNS records, or portal submissions were changed during this review. Existing uncommitted source and dependency changes were preserved.

## Access and TAC instructions verified

- SenderWho mail is accessible through the existing signed-in Chrome session for `senderwho.app@gmail.com`. A Gmail connector is not installed; access was verified through the browser.
- The signed-in ESOF/CASA evidence page was read. Its live counts are **24 Pass, 12 Fail, 12 N/A**. All twelve failed-control comments were inspected and match the request.
- The automated review notification is dated 22 October 2026. It says not to reply to that notification and lists `google@tacsecurity.com` for inquiries.
- The latest human response in **Urgent: CASA Assessment Review Request – SenderWho**, dated 22 October, asks the developer to review results, re-upload evidence for the respective failed checks, and notify TAC once updated evidence is uploaded. The thread includes CASA Support and Assessor Team03; visible addresses include `casasupport@tacsecurity.com` and `AssessorTeam3@tacsecurity.com`.
- No message was sent, no evidence was uploaded, and no checklist attestation was made.
- Follow-up access: the signed-in **Ravindu** Chrome profile provides SenderWho Hostinger website management and DNS administration. See the production findings below. Production log content, secrets permissions/audit logs, and two test accounts remain unverified until explicitly recorded.

## Follow-up: Hostinger and DNS inspection

These observations supersede earlier statements below that deployment settings or a DNS export had not yet been obtained. They do not change any TAC control status.

### Deployed release and vulnerability findings

The SenderWho dashboard identifies a **Business web-app plan**, NestJS, Node **22.x**, and the current completed deployment as:

- Uploaded archive: `SenderWho-Hostinger-Backend-Microsoft-v24.zip`.
- Deployed timestamp displayed by hPanel: `2026-10-12 14:25` (dashboard timezone not established).
- Build/root settings: root `./`, build/output shown as Default.
- Latest vulnerability scan timestamp displayed: `2026-10-22 23:32` (dashboard timezone not established).
- **57 findings: 3 Critical, 31 High, 21 Moderate, 2 Low.** The report says manual patching is required and scans run automatically after redeployment.

This is a significant distinction from the clean current local npm audit. Hostinger lists older dependency versions in the deployed inventory. A clean local scan must not be submitted as proof that production has been patched. Some findings, such as Handlebars, may be build/development dependencies; establish their presence and reachability before documenting treatment. The initial review read the first ten report rows, not all 57 individual findings. CVE identifiers and upgrade targets below are transcribed from Hostinger and have not been independently validated against upstream advisories.

| Hostinger-reported CVE | Package in hosting report | Hostinger suggested target | Current local lockfile |
|---|---|---|---|
| CVE-2026-106446 | handlebars 4.7.9, Critical | 4.7.10 | 4.7.10, dev dependency |
| CVE-2026-106445 | handlebars 4.7.9, Critical | 4.7.10 | 4.7.10, dev dependency |
| CVE-2026-90711 | proxy-addr 2.0.7, Critical | 2.0.8 | 2.0.8 |
| CVE-2026-107385 | mariadb 3.4.5, High | 3.4.7 | 3.5.4 |
| CVE-2026-107384 | mariadb 3.4.5, High | 3.4.7 | 3.5.4 |
| CVE-2026-107383 | mariadb 3.4.5, High | 3.4.7 | 3.5.4 |
| CVE-2026-87776 | compression 1.8.1, High | 1.8.2 | 1.8.2 |
| CVE-2026-102278 | brace-expansion 1.1.16, High | 1.1.20 | resolved dev copies include 1.1.21 |
| CVE-2026-102278 | brace-expansion 5.0.7, High | 5.0.11 | 5.0.12, dev dependency |
| CVE-2026-102276 | brace-expansion 1.1.16, High | 1.1.19 | resolved dev copies include 1.1.21 |

Required treatment: review all hosting findings, build and test a release from the corrected lockfile with the crypto/input/logging fixes, deploy that release, and verify the resulting hosting scan and release inventory. Do not redeploy the old archive and assume its dependencies will be repaired. No deployment or configuration modification was performed during this inspection.

### Production flags and secret storage observations

The following non-secret values were individually revealed in the environment-variable UI, read, and hidden again:

| Key | Actual hPanel value |
|---|---|
| NODE_ENV | production |
| MOCK_DATA_ENABLED | false |
| SWAGGER_ENABLED | false |

The UI masks values by default and provides separate per-value Show, Update, and Delete controls. Variable names confirmed include `YAHOO_CLIENT_SECRET`, `DB_PASSWORD`, `TOKEN_ENCRYPTION_KEYS`, and `TOKEN_ENCRYPTION_ACTIVE_KEY_ID`; secret values were not revealed. This establishes that sensitive configuration is held in hPanel environment variables, but does not establish encryption at rest by the host, least-privilege runtime access, access audits, generation entropy, rotation history, or TAC acceptance as a dedicated secrets-management solution.

### Runtime log inspection

The hPanel Runtime Logs view was opened with its displayed **Last 1 hour** filter. The captured view includes startup events, and `application.starting` reports the actual runtime as **Node v22.23.4**. Observed event names:

`database.configuration.loaded`, `database.tcp_connection.succeeded`, `application.starting`, `database.migrations.starting`, `database.connection.starting`, `database.migrations.completed`, `database.prisma_connection.starting`, `database.prisma_connection.succeeded`, `application.listening`, `application.ready`.

The visible structured-log fields include `host`, `port`, `user`, `database`, **`passwordLength`**, and **`passwordHasLeadingOrTrailingWhitespace`**. This confirms that unnecessary credential metadata is present in actual deployed startup logging. Values were omitted from this review artifact. Remove these password metadata fields and minimize database identifiers in routine production logs.

No bearer-token or OAuth code/state query pattern was detected in that captured startup view. This is **not** evidence that a real login or hosting/proxy access log is clean: neither was captured, and the scope/retention/completeness of the displayed log view has not been established. A fresh controlled test login, application logs, and proxy/CDN/access logs remain required for 6.5.1. Account-sharing/permissions, hosting activity logs, and secret-specific access auditing remain unverified. Browser focus repeatedly switched to the TAC profile during inspection; do not infer successful navigation or inspection of those remaining views.

### DNS export and initial target mapping

Hostinger's DNS editor successfully exported the current zone on **2026-10-23 06:17:58 UTC / 11:47:58 Asia/Colombo**. The original download was `senderwho.com.txt`; the review copy is `output/casa-production-review-2026-10-23/senderwho.com.zone.txt`, SHA-256 `0a42551f6553ca8da21b6b1c5df6c5c22190dbd7d814e16b6aec5c52b473f4cd`.

Public NS queries match the export: `helios.dns-parking.com` and `aster.dns-parking.com`. The Hostinger editor describes this as an external domain and displays GoDaddy as the registrar. DNS hosting and registrar are different services; registrar account access was not checked.

| Record group | Destination | Verified and remaining work |
|---|---|---|
| Apex ALIAS | senderwho.com.cdn.hstgr.net | SenderWho is assigned and running in this Hostinger account; public apex resolves and API responded earlier. Capture CDN/domain assignment evidence with final release. |
| www CNAME | www.senderwho.com.cdn.hstgr.net | Public CNAME matches export; verify hostname response and explicit Hostinger domain/CDN association. |
| autodiscover/autoconfig CNAMEs | autodiscover.mail.hostinger.com / autoconfig.mail.hostinger.com | Both service destinations resolve. Confirm whether SenderWho Hostinger email is active and needed. Resolution alone does not establish an active domain-specific subscription. |
| Apex MX | mx1.hostinger.com (priority 5), mx2.hostinger.com (priority 10) | Both destinations resolve; confirm account-level email assignment/use. |
| Three DKIM selector CNAMEs | hostingermail-a/b/c.dkim.mail.hostinger.com | Public selector a resolves to a nonempty RSA DKIM record; b and c respond with empty DKIM public-key fields. Determine provider rotation/reserved-selector behavior before treating these as dangling or changing them. |
| TXT | SPF, DMARC, Google and Yahoo verification | Present in export; not third-party web-hosting claims. No changes made. |

No unused record was deleted, and no conclusion of complete takeover resistance has been made. Finish service assignment/control checks and account for any names managed outside this zone or delegated elsewhere.

## Checks performed

### Current backend audit

`npm audit --json` ran successfully against the registry from `server` on 23 October 2026. It returned exit code 0 and **0 vulnerabilities** across all reported severity levels, including development dependencies. The report counts 815 total dependencies. This is point-in-time npm advisory coverage for the local dependency tree, not proof of production deployment or Flutter/native coverage.

The backend manifest dependency map agrees with the root package-lock dependency map. `server/package.json` and `server/package-lock.json` already have uncommitted changes. The working tree is therefore not represented by HEAD alone.

| Artifact | SHA-256 at review |
|---|---|
| server/package-lock.json | 79ff12912271e83bf27bfaf3a1c5a4ad2b12c6d1cd7960d436a3e0010f4d0f1d |
| senderwho/pubspec.lock | 5b96d5764e8b5de364991ebf1f280c34f752e966172f0f0c9861b45010a765d8 |
| senderwho/ios/Podfile.lock | 7a932c01cd2615e2bbe7adf1908edfa8ffc7a1e9c79fa6b59ce89943000f103b |

HEAD: `5e238111b28e1e0233f7bf110b2f8870763a1506` (plus existing working-tree changes).

The original `output/casa-backend-npm-audit.json` reports 1 critical, 12 high, and 4 moderate findings. The two later `*-updated.json` reports show zero. Preserve the initial report as remediation history, but clearly identify the fresh clean result and exact release rather than using the initial vulnerable report as final evidence. Itemize historical advisories/CVEs, affected versions, patched versions, and treatment in the final evidence package. Do not label old reports as fresh scans.

Flutter and native dependencies have not received a new vulnerability scan in this review. `flutter pub outdated`, compilation, tests, and SBOM generation alone do not establish absence of vulnerabilities. Cover the resolved Dart packages, Android Gradle/Maven dependencies and runtime, iOS CocoaPods dependencies, SDKs, and the actual distributed build. Verify scanner ecosystem support and document any blind spots. Existing CI configuration is not proof of an executed successful scan.

### Backend tests

`npm test -- --runInBand`: **40 suites passed, 3 failed; 187 tests passed, 4 failed**.

Every failure reports that `global.fetch` is absent in the Jest environment:

- `providers/microsoft/microsoft-graph.client.spec.ts`: two failures.
- `providers/microsoft/microsoft-token.service.spec.ts`: one failure.
- `providers/gmail/gmail.client.spec.ts`: one failure.

The host runs Node v26.3.1, where a direct check shows `fetch` is available. CI and shared-hosting instructions specify Node 22. The precise Jest/runtime compatibility cause remains unverified. Resolve or reproduce under the supported deployment runtime before claiming a clean regression suite. Passing ownership unit tests do not replace a complete route-to-operation matrix or real two-account integration tests.

### Public production observations

Read-only requests to `https://senderwho.com` at approximately **11:31 AM Asia/Colombo** on 23 October 2026 returned:

| Request | Result | Meaning and limit |
|---|---|---|
| GET /api/v1/docs | 404, generic JSON error | Swagger is not served at this expected path. Other console paths and deployed flags were not exhaustively checked. |
| GET /api/v1/email-accounts with deliberately invalid bearer token | 401, `The app session is invalid or expired.` | A protected endpoint rejects this invalid token without an external stack trace. This does not cover every JWT or cryptographic failure. |
| GET /api/v1/health/ready | 200, mysql up and databaseQueue up | Production reports readiness. This does not prove all production debug/mock flags. |
| GET /api/v1/users/me | 404 | This GET route does not exist in current source; do not count this request as an authentication test. |

Responses include Hostinger/hPanel headers, HSTS, no-store cache control, no-referrer, and CSP. These observations support Hostinger serving the endpoint; they do not establish hosting plan, account ownership, or administrative permissions.

## Twelve-control action list

| Control | Verified local observation | Required next step and evidence |
|---|---|---|
| 2.2.2 | App session revocation exists. No RISC receiver was found in the scoped auth search. TAC rejects manual sign-out as sufficient evidence of password-change/recovery behavior. | Ask TAC for the OAuth-only requirement, applicable provider events and expected coverage for recovery, Google Workspace, and any enabled Microsoft/Yahoo login. Agree acceptance criteria before selecting an implementation. Keep this control open. |
| 3.1.4 | `docs/casa_access_control_evidence.txt` already lists many resource routes. Ownership unit tests exist, including mixed-owner bulk rejection. | Turn the existing text into a complete matrix of every endpoint, operation, controller/service, ownership predicate, and negative test. Include create/list/export/update/delete, sessions, jobs, and batch operations. Run two-account integration tests before final submission. |
| 4.1.3 | AES-256-GCM uses 32-byte keys and fresh 12-byte IVs. Existing instructions prescribe `openssl rand -hex 64` for signing material and `openssl rand -base64 32` for encryption keys. Startup only checks JWT secret length, which does not prove random generation or entropy. | Document actual production generation, sizes, custody, access, rotation, revocation, and emergency recovery. Show metadata and redacted operational evidence. Do not reveal keys or treat generation instructions as proof they were followed. |
| 4.1.4 | `token-encryption.service.ts` still throws ServiceUnavailableException messages containing a key ID and configuration names. GCM plaintext is only returned after `final()` succeeds. | Normalize externally visible crypto failures; preserve safe internal event codes. Test missing/retired keys, malformed payloads, wrong context, invalid tag/IV, corrupted ciphertext, and invalid tokens. Assert safe HTTP errors and no plaintext return. Also inspect OAuth and provider error translation. |
| 5.1.1 | `main.ts` installs JSON and URL-encoded parsers plus DTO validation. No explicit duplicate-parameter rejection policy was found there. | Define handling across query, form, and JSON inputs. Reject security/business-sensitive duplicates before parsers discard ambiguity, including escaped duplicate JSON member names where applicable. Test identical/conflicting duplicates, OAuth state/code, pagination/IDs, nested values, and allowed bulk arrays. |
| 5.1.3 | Searches across `server/src`, `server/scripts`, `senderwho/lib`, and `senderwho/web` found no eval/new Function invocation. `node-entry.js` spawns the Node executable using CLI arguments; regex `.exec()` and Dart Function type matches are not dynamic code evaluation. | Produce a reproducible source-review report with exact patterns, exclusions, file scope/counts, reviewed matches, and representative input-to-Prisma/DTO handling. Confirm the launcher cannot be reached with HTTP-controlled arguments. The initial searches alone are not a complete data-flow review. |
| 5.1.7 | OAuth title/message are HTML escaped; the app callback URL is built from a fixed scheme/path and boolean status in HTML, URL, and script contexts. Public pages escape attributes and use a fixed mailto prefix for configured support email. | Document every interpolation and its context/trust source, including trusted raw section HTML. Add hostile-input regression checks for text, quoted attributes, URLs, script interpolation, and DOM sinks. The OAuth script nonce is static and should not be represented as a fresh nonce security control. Check effective deployed CSP as well as template policy. No user-input XSS exploit was established in this initial review. |
| 6.1.1 | Current backend npm audit is clean; old submitted report was vulnerable. Mobile/native coverage and deployed release identity remain unverified. | Complete supported ecosystem scans, retain raw outputs and release hashes, itemize historical CVEs/advisories and fixes, verify deployment, then submit the final clean evidence. Do not close solely on the npm result. |
| 6.2.1 | Source rejects production mock mode/Swagger. Public docs path is 404 and invalid-token response has no stack. | Capture actual deployed NODE_ENV, mock/Swagger flags, build/entry command, runtime/release version, and representative malformed/error responses. Enumerate developer consoles. Keep secret values hidden. |
| 6.4.1 | TAC saw DNS screenshots, but they did not establish active ownership of third-party targets. No DNS export was obtained here. | Export all authoritative records, map in-scope hostnames and CNAME/delegation chains to services, verify each target is active and claimed in the owner account, and remediate confirmed unused/dangling records. Public DNS resolution alone does not prove control. |
| 6.5.1 | HTTP interceptor omits query values, headers and bodies. `main.ts` startup logs include database host/user/name, password length/whitespace metadata, and raw startup error message/stack. Example Caddy logging has no explicit query-value redaction. Actual Hostinger access logs were not read. | Remove unnecessary startup metadata and review raw-error handling; inspect the actual hosting/proxy configuration. Run a real test login and correlate app plus CDN/proxy/access logs, especially OAuth code/state URLs. Demonstrate absence of credentials, tokens, and sensitive query values before final evidence. Example Caddy configuration is not proof it is deployed. |
| 6.7.1 | Backend runtime injection, provider-token encryption, refresh-token hashes and encryption key-ring support exist. Shared-hosting instructions use hPanel variables; older architecture docs describe a VPS root-owned file. Neither establishes today's actual secrets store/access auditing. | Confirm deployed architecture, actual store, owner/admin/runtime access, access logs/monitoring, rotation and revocation. Ask TAC whether current hPanel storage can meet their dedicated-store/managed-access requirement; if insufficient, choose a supported solution with audited least-privilege runtime access. |

## Recommended sequence

1. Preserve the fresh clean backend dependency result; complete mobile/native scans and investigate the four Jest failures under Node 22. Tie results to a deployable release.
2. Fix cryptographic error disclosure, duplicate parsing, and unnecessary startup logging. Add meaningful negative tests, including real HTTP serialization checks.
3. Complete the CRUD ownership inventory, dynamic execution report, and XSS context review using existing evidence as a starting point.
4. Inspect the real Hostinger deployment, authoritative DNS, secrets permissions/auditing, and real-login logs. Two disposable test identities are needed for cross-user/session integration tests; do not share their passwords in evidence.
5. Re-upload only the twelve failed controls with verified results and artifacts. Follow TAC's human email instruction to notify the support/assessor thread after upload. Request final review without asserting that a pass is guaranteed.

## Draft clarification message — not sent

To: existing CASA Support/Assessor Team03 email thread.

Subject: SenderWho — clarification for controls 2.2.2 and 6.7.1 before evidence update

Hello TAC team,

We have reviewed the twelve failed controls and are preparing corrected evidence.

For 2.2.2, SenderWho uses external OAuth authentication and has no local password-change or password-recovery flow. We can revoke SenderWho access and refresh sessions but cannot terminate the identity provider's own sessions. Please confirm the required provider-event handling and test cases for password change and recovery in this scope. Would validated Google Cross-Account Protection events followed by application-session revocation meet your requirement, and what alternative is required for Google Workspace or other enabled providers/events it does not cover?

For 6.7.1, please confirm what dedicated secrets-store, runtime access-control, and access-audit evidence you require if the production deployment uses Hostinger hPanel environment variables. We will verify the actual deployed controls and remediate any gaps before claiming compliance.

We will upload updated evidence for the failed controls and notify this thread once complete, as requested.

Thank you.

## References and limits

- Google Cross-Account Protection: https://developers.google.com/identity/protocols/risc — signed security events can drive application-side actions. Google's current documentation explicitly says it does not send events for Google Workspace users. Do not assume it covers every password change/recovery scenario.
- OWASP Secrets Management: https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html — access control, auditing, lifecycle, rotation and revocation.
- The latest human TAC thread and live portal comments are the assessment-specific instructions. The plan above is our interpretation of work needed; only TAC can accept evidence or change control status.
