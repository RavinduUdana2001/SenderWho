# Responsive account controls and completed sync release

## Client changes

- The account drawer uses 82% of the available width, capped at 312 logical pixels. Mailbox switching, Settings, and other core destinations remain available. Search / Filter was removed from the drawer; search and category filtering remain on Inbox and Senders.
- Privacy & Security no longer offers a provider password-change report or account-deletion controls. Settings no longer links to account deletion. The existing web/API deletion path concerns SenderWho data and provider access only; it does not delete a Google account or Gmail messages. No real account deletion was performed during verification.
- Mailbox access and active SenderWho sessions remain manageable. Long device names wrap, session sign-out actions move beneath the device details on small screens or at large text sizes, and settings descriptions wrap instead of hiding instructions in one-line ellipses.
- Privacy copy and headers are shorter. The sign-out confirmation says “Sign out?” and “Your mailboxes stay connected.” Rate-limit notices use a compact, neutral paused state; Reconnect is reserved for access problems. Scheduled retries have a disabled “Retry scheduled” action rather than inviting an immediate retry.
- When Google rejects a grant, the existing backend marks that mailbox disconnected and requires reauthorization. The client says “Gmail access changed. Sign in again to reconnect this mailbox.” It does not assert that the password changed: invalid grants have several possible causes, and detection occurs when Google rejects an API/token request, not instantaneously at password-change time. See [Google OAuth token expiration](https://developers.google.com/identity/protocols/oauth2/#expiration).

## Backend v32

The approved `SenderWho-Hostinger-Mailbox-Fix-v32.zip` is the current completed Hostinger deployment, ID `01a1a6d3-3068-70bd-a688-7f3d04a86f35`, submitted 2026-11-04 19:20:20 and completed around 19:21 Asia/Colombo. Build time: 44 seconds. Node 22, NestJS, existing environment and database retained.

Archive SHA-256: `94f95d82abbee59b428b3f7c58feda3100edaeb0de6911b1f129a430cfb8d9e2`.

The live readiness check on 2026-11-05 reported `2026-11-04-mailbox-v3` with MySQL, database queue, job worker, worker leases, scan scheduler, and data retention all up.

The release preserves fully completed page checkpoints, saves successful batch items even when another item fails, updates sender counts after partial progress, paces metadata imports, and carries provider cooldowns into bounded durable retries. It exposes actual queued retry times and prevents Scan now from resetting a queued cooldown. Google documents per-user quota limits and notes that batch calls still count individually: [Gmail quota](https://developers.google.com/workspace/gmail/api/reference/quota), [Gmail batch requests](https://developers.google.com/workspace/gmail/api/guides/batch).

## Verification

- Backend release: all 367 tests passed across 61 suites; build, ESLint, and Prettier passed. Eleven focused revocation, checkpoint, ownership, and SenderWho-deletion tests were rechecked successfully on November 5.
- Flutter: all 243 tests passed, with the existing preview-only test skipped. Every named screen was also reviewed on both iOS and Android variants, including 280-pixel phones. The extra-small review exposed and fixed an Unsubscribe action-row overflow; action buttons now wrap beneath sender details when needed. Sixteen new account-layout cases exercise iOS and Android platform variants at 280-pixel phones, 320-pixel phones with 200% text, short landscape layouts, and tablets with 200% text, in both themes. Long device names and working session revocation are included. These are automated layout tests, not certification on every physical handset.
- Analyzer is clean. Additional focused tests passed for friendly auth messages, background progress, and account recovery controls after the full run.
- The updated iPhone 17 Pro simulator visibly shows the narrower menu, simplified Privacy & Security page, and no in-app account deletion or provider-password-change control.
- After one secondary-mailbox Scan now, its Inbox rose from the previously stored 282 messages to 354, 492, 732, 892, and 1,630 during observation. Senders increased from 45 to 139. Manage Accounts showed 1,340 completed-page messages processed, with later continuation scans still running. Switching to the primary mailbox loaded its separate 1,133-message Inbox; switching back restored the secondary mailbox and its identity. The scan is importing older mail in the background; a completed full historical backfill is not claimed. This is an ongoing automatic import, with saved progress and usable lists throughout.

## Consistent Back navigation follow-up

Main Inbox, Senders, Unsubscribe, and Clean now use the same route and header rules whether selected from the drawer or bottom bar. They have no app-bar Back arrow. Filtered mail/sender lists and secondary pages retain a single Back action when there is a real previous route; standalone root screens do not display a nonworking Back button. The profile remains in its existing fixed position. Long secondary-page titles may wrap to two lines.

Selecting a main tab closes utility/detail pages above the mailbox stack, rather than leaving Settings or a message immediately underneath a newly selected tab. Reusing an existing main tab returns to it without adding duplicates. Settings, Privacy, and other utility pages keep the originating mailbox tab highlighted. The drawer no longer marks Archived Mail as the main Inbox, so choosing Email Inbox from a filtered list correctly exits the filtered view.

Verification: all 248 Flutter tests passed (one existing preview-only test skipped). New iOS/Android navigation tests cover drawer and bottom-tab parity, Privacy → Settings → Inbox returns, exiting utility routes, leaving archived mail, retaining Back in filtered lists, and hiding Back at a standalone root. Message auto-read regression fixtures now use an actual pushed message route and verify leaving early cancels the timer. The rebuilt simulator visibly confirms the updated privacy page and the same return behavior. No additional backend release was required.
