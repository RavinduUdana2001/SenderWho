# Entry experience and account switching — 4 November 2026

## Delivered behavior

Welcome and sign-in now share a restrained violet backdrop, a larger branded illustration, clearer type hierarchy, and a single primary welcome action. Sign-in and account creation continue through the existing provider flow; no extra password form or unsupported authentication feature was added. Remembered accounts, another-account selection, provider availability, cancellation, retry, and legal links remain available. Layouts scroll on short screens and at enlarged text sizes.

Splash uses one 900 ms brand entrance with expanding, fading rings and a short outgoing transition. There is no bottom loading indicator and no artificial five-second delay. Startup restoration yields after four seconds, allowing the welcome screen to appear within the intended five-second budget under the tested clock. A late successful restoration saves the rotated credentials and resumes the session from welcome. Opening sign-in takes precedence over automatic navigation. Physical-device rendering latency is not certified by widget tests.

Previously, changing the current mailbox changed the account used for default actions while the main data lists remained combined. Messages, senders, category counts, search, unsubscribe candidates, cleanup suggestions/jobs, alerts, activity, and health/dashboard metrics now follow the selected connected account. The server retains user ownership checks and excludes disconnected accounts. Explicit message and job actions remain tied to their existing IDs and ownership checks. No database migration is required.

After linking a mailbox, the app discovers the updated accounts before notifying the screens. The header identifies the current email address when multiple accounts are connected. Switching clears the old navigation history and reloads account context. Inbox refreshes automatically during a pending scan, with an explanatory empty state. Session changes clear cached profile/mailbox state, ignore old HTTP responses, and serialize credential writes so a pending write cannot undo sign-out.

## Verification

- **183 Flutter tests passed**, one preview-only test skipped.
- **298 backend tests passed** across 54 suites.
- Flutter analyzer: no issues. Backend TypeScript check: passed. `git diff --check`: passed.
- New regressions cover slow startup and late recovery, cancelled OAuth followed by a new sign-in, stale unauthorized responses, sign-out during a secure-storage write, scanning refresh, two-mailbox list/count separation, switching back, and exclusion of foreign/disconnected metadata.
- Entry layouts checked at 150% and 200% text on a compact phone in both themes. Full existing app navigation, theme, message actions, and responsive-layout checks remain passing.
- Light/dark rendered entry previews are in `senderwho/tmp/entry-refresh-2026-11-04/`. The temporary capture test was removed. Previews use locally loaded Arial and Material icons.

The installed Node 26/Jest combination loses web globals after mock restoration. The full backend suite was run with a temporary `setupFilesAfterEnv` shim that reinstates Node's standard web globals before each test, with localhost HTTP binding allowed. No runtime dependency or Jest configuration was changed.

Live Google authorization, provider scanning, and account switching against the user's real mailboxes require a device/session check. Automated tests use controlled provider responses and database fixtures. Apply the backend changes and hot-restart the Flutter app together to use the new mailbox behavior.
