# Mailbox API release and live verification

The screenshots show HTTP query validation rejecting `emailAccountId`. The current Flutter app sends that field to keep Inbox, Senders, and subscription results scoped to the chosen mailbox. The local backend DTOs accept it; the API reached by the screenshots does not. Restarting the Flutter app alone cannot update a hosted backend.

Use the numbered `output/SenderWho-Hostinger-Mailbox-Fix-*.zip` source release for the existing `senderwho.com` Hostinger application. This is a backend archive with the lockfile, not a Flutter web release. Local `.env` files, database contents, credentials, `node_modules`, and old compiled `dist` files are excluded. Package a new immutable release with `python3 server/scripts/package-hostinger-release.py --release-number <new-number>` from the repository root; an existing release archive cannot be overwritten.

Keep the existing database, OAuth callback URLs, and hPanel environment variables. In the existing application's deployment flow, upload the archive and use Node.js 22, build command `npm run build`, output directory `dist`, entry file `main.js`. Uploading a ZIP without completing the build/deploy does not update the running service. The packaged startup applies committed migrations if any remain pending; the mailbox fixes themselves add no schema migration.

After deployment, `/api/v1/health/live` must show `apiContractVersion: "2026-11-04-mailbox-v1"`, and `/api/v1/health/ready` must be ready. With an authenticated test account, check the exact calls below return 200, with totals and items from the selected owned mailbox:

```text
GET /api/v1/senders?page=1&limit=25&kind=ALL&control=ALL&emailAccountId=<selected-account-id>
GET /api/v1/emails?page=1&limit=25&mailbox=INBOX&emailAccountId=<selected-account-id>
```

Then check category tabs and the filter sheet with Newsletters, Finance, and an empty-result category; switch between two connected mailboxes and back. Unknown query parameters must still return 400. Do not remove mailbox/category parameters as a workaround: older server implementations may return combined account data or ignore categories.

The HTTP contract regression exercises both real controllers and DTOs with strict query validation for every sender category. Selected mailbox ownership and filtering predicates are covered separately by mailbox view/service tests. Local tests do not establish that the ZIP has been deployed or that live Gmail permission grants are valid.

## Deployment completed

With the user's explicit approval, `SenderWho-Hostinger-Mailbox-Fix-v30.zip` was uploaded and deployed to the existing Hostinger `senderwho.com` application on 2026-11-04, around 16:02 Asia/Colombo. Hostinger reported the new release as **Current / Completed** under deployment ID `01a1a61d-2b5e-7101-bb42-1c62782e4548`. The existing build settings and environment variables were retained.

Archive SHA-256: `4284e0b26889eb374179f7c57450984cd0081cd1aa84b9a54e80c306477bab17`.

Live verification after restart:

- `/api/v1/health/live` reports `apiContractVersion: "2026-11-04-mailbox-v1"`.
- `/api/v1/health/ready` reports ready; MySQL, database queue, job worker, worker leases, scan scheduler, and retention are all up.
- In the running iPhone 17 Pro simulator, the primary mailbox loads 1,126 Inbox messages and 972 senders. The secondary mailbox loads its own 282 Inbox messages and 43 senders.
- Inbox Finance filtering returns populated results; Senders Finance filtering returns two sender rows. Newsletters gives the expected empty results, and clearing filters restores the full mailbox list.
- The secondary mailbox retains a provider permission warning from its failed Gmail scan. Reconnect opens Google sign-in for that mailbox; fresh syncing cannot be certified until its Google authentication and permission review are completed. Cached metadata remains visible.

Validation for this release: all 348 backend tests passed across 59 suites, 18 focused Flutter tests passed, backend build/lint/format and Flutter analysis passed. The archive's file hashes and secret-file exclusions were verified before upload. No pending source schema change was introduced by this mailbox fix.

## Google reconnect follow-up

The user completed a secondary-mailbox reconnect, but the callback rejected the grant with “Google did not grant all required SenderWho permissions.” A separate backend validation defect was reproduced: Google can return `https://www.googleapis.com/auth/userinfo.profile` for the requested `profile` scope; comparing only literal names rejects an otherwise complete grant. The check now accepts the known equivalent identity names. Gmail modify permission, OpenID, and email/profile identity access remain required; unknown/lookalike names and read-only Gmail grants still fail. See [Google's scope-response guidance](https://developers.google.com/identity/protocols/oauth2).

Release v31 contains that follow-up, with API contract marker `2026-11-04-mailbox-v2`. All 360 backend tests across 60 suites, build, lint, and formatting passed. Its SHA-256 is `7c33329939eb6858c06552b54e0c2be42f73a33d4810deda8678eb5497c93ba7`. A fresh reconnect is necessary because the failed authorization code has already been exchanged; the failed callback does not save its provider tokens.

The user explicitly approved v31 after the hosting upload confirmation review required approval for that specific follow-up. It was deployed to the existing application under Hostinger deployment ID `01a1a631-397e-7120-8038-73a1415d1ea0`, submitted around 16:23 Asia/Colombo. The live readiness endpoint subsequently reported `2026-11-04-mailbox-v2` and all six database/worker components up. A new secondary-mailbox reconnect was requested to verify that fresh provider access is now accepted.

The user subsequently completed that reconnect. The callback accepted the grant, and a fresh scan increased the secondary mailbox from 43 to 45 senders. Gmail then reported a temporary scan rate limit. One further Scan now was started after a cooldown; its final result was not observed because the simulator window was unavailable at the next check. The fresh access acceptance is verified; a completed full backfill is still unverified. Repeated reconnects are unnecessary for a provider rate limit.

## Inbox header and selected mailbox identity

The follow-up Flutter changes keep Search and Select as accessible icon buttons on the same row as the centered Inbox title. Icon-only action groups no longer trigger a second header row on compact displays or at large text sizes. Selection/cancellation and message search remain functional.

The header and drawer now resolve their visible identity from `activeMailbox`. A different mailbox uses its own display name (or email initials when the provider name is generic), and the drawer shows its email address. The original login profile photo is only used when its email matches the selected mailbox; it is never reused for a different account. The Profile details page continues to describe the SenderWho sign-in account.

Validation: all 213 Flutter tests passed, with one existing preview-only test skipped. Flutter analysis reports no issues. New checks cover repeated mailbox switches, removal of stale profile photos, one-row Inbox actions, centered titles, working search/selection controls, and non-overlapping layouts at 320/390/600 logical pixels, including 200% text in both themes. Light/dark previews were rendered and visually reviewed. These Flutter changes require reloading/rebuilding the client; they do not require another backend deployment.

## Resumable-sync follow-up (v32)

The user explicitly approved v32. Hostinger confirms it is Current / Completed under deployment ID `01a1a6d3-3068-70bd-a688-7f3d04a86f35` (2026-11-04 around 19:21 Asia/Colombo). The live readiness check on November 5 reports `2026-11-04-mailbox-v3` with all worker/database components up. All 367 backend tests passed. SHA-256: `94f95d82abbee59b428b3f7c58feda3100edaeb0de6911b1f129a430cfb8d9e2`.

This release adds paced metadata reads, completed-page checkpoints, accurate partial-import sender counts, retained successful batch items, bounded durable cooldown retries, and visible retry scheduling. After one secondary-mailbox scan was started on November 5, its Inbox increased from 282 previously stored messages to over 1,600 while importing older mail. Sender rows increased from 45 to 139, and completed-page progress was visible in Manage Accounts. Account switching loaded the primary mailbox’s separate 1,133-message Inbox, then restored the secondary mailbox correctly. Full historical import continues automatically in the background. See [the November 5 account and UI review](responsive_accounts_review_2026-11-05.md) for implementation and verification details.
