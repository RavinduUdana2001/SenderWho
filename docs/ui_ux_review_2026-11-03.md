# SenderWho UI/UX review — 3 November 2026

The main usability problems were oversized sections, competing actions, technical wording, and important controls appearing below unnecessary information. The changes keep the Yahoo-inspired compact mailbox layout and apply that direction to the supporting screens.

| Area | Finding | Change |
| --- | --- | --- |
| Unsubscribe | Large cards and multiple equally prominent actions made the primary task difficult to identify. | Flat sender rows, one visible Unsubscribe/Retry action, optional search, clear progress/retry filters, and secondary actions in a menu. |
| Bulk unsubscribe | A prominent all-senders action made it hard to work on just a few subscriptions. | Long-press or choose Select subscriptions, select specific senders, then confirm the selected batch. Unsubscribe all shown remains available in the menu. |
| Refresh and recovery | Refresh could replace useful loaded data; an asynchronous assignment inside setState also caused a runtime assertion. | Keep loaded subscriptions when refresh fails, display an inline retry, and fix the state update. |
| Search | Expanded filters pushed the Search action below the first screen. | Start with the search field, a compact filter summary, and a visible Search button. Advanced filters remain expandable. |
| Bulk Clean | Large statistics and repetitive instructions delayed access to cleanup groups. | Show groups earlier, use a compact selection estimate, and retain exact-preview confirmation before moving messages. |
| Accounts | Provider connection controls competed with the existing account list. | Collapse provider options under Add another mailbox; the drawer's Add action opens that section directly. Improve wrapping of account labels and status. |
| Account scope | Inbox/sender lists aggregate connected accounts, while the current mailbox sets default account actions. | Explain this distinction in account management and label combined mailbox lists when multiple accounts are loaded. No backend filtering behavior was changed. |
| Categories and Top Senders | Decorative cards and rankings made the lists unnecessarily large. | Compact rows with names, relevant counts, and direct navigation. |
| Activity, Dashboard, Inbox Health | Large decorative summaries dominated useful information. | Quieter summaries, compact statistics, and consistent surfaces and typography. |
| Security Alerts | A large overview competed with the actual alerts. | Compact count and risk filters, separated alert rows, and plain-language empty states. |
| Alert details | Review actions appeared after repeated sender/risk metadata. | Place actions before expandable technical information. Keep additional evidence visible when available; avoid repeating the summary reason. |
| Privacy and Profile | Advanced password-change help dominated active devices; long detail values wrapped awkwardly. | Expand password-change help on demand, show active devices earlier, and stack long profile values. |
| Shared controls | Buttons, filters, loading, error, and empty states varied between screens. | Use consistent theme colors, flatter primary buttons, generous tap targets, and readable recovery messages. |
| Small screens | Account status labels, subscription actions/selection, and cleanup review controls could overflow with larger text. | Allow controls to wrap or stack without shrinking the user's text. |

## Validation

Final result: **134 Flutter tests passed**, with one preview-only test skipped. `flutter analyze` reports no issues; `git diff --check` is clean.

- Exercise all 22 named screens using populated API fixtures in light mode, dark mode, and at 320×640 with 130% text scaling. Scroll supporting screens to check their lower content as well.
- Check subscription search, retry filtering, selective batch confirmation, trust actions, restored jobs, polling recovery, and retention of loaded rows after refresh failure.
- Check Add another mailbox → expanded provider options → Back to Senders, and that advanced Search controls remain available.
- Retain the existing navigation, theme persistence/rollback, message reading, mailbox actions, cleanup, account-management, and repository regression tests.
- Visually inspect rendered screens. Captures are in `senderwho/tmp/ui-review-2026-11-03/`.

These are local Flutter widget/API-fixture checks. Real Google, Microsoft, and Yahoo authorization, provider-side delivery changes, and native-device performance require live account/device verification; this review does not claim those flows were exercised against providers.

## Product behavior to keep clear

An unsubscribe request being sent does not guarantee the provider has already stopped sending mail. Existing messages remain in the mailbox. Only senders with a supported unsubscribe option appear in this list.

Security risk filters apply to alerts already loaded by the paginated list; users can load additional alerts. Account selection does not currently filter the combined Inbox and Senders data by mailbox. Supporting a per-account inbox would require a separate backend/data-flow change.
