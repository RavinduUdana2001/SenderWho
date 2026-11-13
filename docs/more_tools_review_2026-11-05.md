# More tools review — 5 November 2026

## Changes

- Rebuilt Dashboard around compact mailbox totals, grouped cleanup/subscription/health links, top senders, alerts, and mailbox sync status. Removed the duplicate search field, repeated shortcuts, and oversized scan banner.
- Dashboard totals open their corresponding mailbox filters; sender and alert rows open the selected record. Main destinations use the shared primary navigation, while detail pages retain Back.
- Dashboard retains its last successful overview during a failed refresh, prevents overlapping refreshes, and pauses polling when the app is backgrounded. Scan availability respects active imports, scheduled retries, and reconnect/configuration requirements.
- Bulk Clean uses clearer review/confirmation copy and consistent themed suggestion surfaces. Existing message previews, trusted-sender protection, confirmation, cancellation, and job-result handling remain available.
- Categories, Top Senders, and Activity now support pull-to-refresh with a working error/retry path. Top Senders returns to the primary Senders destination without an unnecessary detail-page Back button.

## Verification

- Flutter suite: 260 tests passed; one existing preview-only test skipped.
- Twelve focused More tools behavior tests cover drawer destinations, exact mailbox/category queries, sender/alert routing, refresh failure and retry, cached results, scan/reconnect status, and account-specific sync requests.
- Existing regression coverage includes unsubscribe pagination/search, cleanup preview/job/cancellation behavior, both iOS and Android widget configurations, small screens, and enlarged text.
- Visually reviewed Dashboard, Bulk Clean, and Activity renders in light and dark themes. Captures are under `senderwho/tmp/more-tools-2026-11-05/`.
- Ran the updated app in the iPhone simulator and checked Dashboard against live mailbox totals. Destructive cleanup and unsubscribe operations were exercised against test responses, without changing live mail.

Widget/layout coverage and the iPhone simulator do not replace physical-device testing on every supported Android and iOS device.
