# Production-readiness fixes — 4 November 2026

This change addresses the eight items from the app audit. Deploy the backend and Flutter changes together. No schema migration is required.

| Audit item | Implemented behavior |
| --- | --- |
| Background failures | Scheduled scan queries, retention runs, worker failure-record writes, and lease heartbeats catch and log sanitized failures. Scan scheduling and worker polling use bounded backoff; retention retries with backoff instead of waiting another day. Runs do not overlap. |
| Worker health | `/api/v1/health/ready` now includes process-local `jobWorker`, `workerLeases`, `scanScheduler`, and `dataRetention` status. Failures or stale successful checks return 503; liveness remains process-only. Claiming pauses while an active lease is uncertain. Lost leases signal cooperative cancellation before subsequent provider actions and prevent completion being reported. Existing owner-checked queue writes and durable retry semantics remain in place. |
| Stalled networking | One 15-second deadline covers connection, response headers, and the entire body, including token refresh. A timeout cancels the stream and signals an abort to the HTTP client without closing the shared client. Retry works on the same client. Search and subscription reads support cancellation; superseded responses cannot replace current results. |
| Mixed searches | Applied query, categories, date/trust options, unread, and attachment flags are immutable snapshots. Loading more after editing any draft option starts page one. New searches supersede old ones; Cancel search clears the busy state and ignores late responses. |
| Unsubscribe pagination | Candidates support validated server-side query, page, limit, current mailbox, and All/In progress/Needs retry filters. Responses include matching totals, `hasMore`, and status information for jobs associated with each page. The app debounces remote search, loads more, keeps rows after page failures, and offers retry. |
| Subscription batch limits | Selecting rows across pages no longer creates oversized requests: action and progress calls are split into at most 25 IDs. A failed action chunk stops further sends and preserves successful chunks plus explicit failures for remaining rows. Poll intervals grow with the number of status chunks. |
| Sender search filters | Unread, attachment, and date restrictions require one message from the sender to satisfy all active message conditions. The message and sender totals use their respective matching predicates. Stable ID tie-breakers are used for pagination. |
| Unsupported notifications | The Security notifications switch is hidden. Stored preferences and the existing API field remain compatible; this change does not claim to implement notification delivery. |
| Settings counts | Archive, Trash, Blocked, and Trusted counts follow the selected mailbox while connected-account/session counts retain their account-wide meaning. |
| CI lint/format | Removed the invalid string escapes in the XSS tests and formatted backend source files, including the three previously failing logger files. Lint and formatting checks pass. |

## Verification

- Flutter: **197 tests passed**, one preview-only test skipped. The new regressions cover stalled headers/bodies, abort signalling, token-refresh body deadlines, a successful retry using the same client, cancelled/overlapping searches, changed-query pagination, remote subscription search beyond page one, failed-page recovery, and 25-item batch limits.
- Backend: **326 tests passed** across 58 suites. New coverage exercises scheduler outages and recovery, nonoverlapping retention retries, failure-record write containment, failed/lost lease handling, unhealthy/stale worker readiness, validated subscription pagination/search/filter ownership, message-constrained sender predicates, and mailbox-scoped settings counts.
- Flutter analyzer, Dart formatting, backend ESLint, backend Prettier, TypeScript/backend build, release web build, and `git diff --check`: passed.
- Local Node 26/Jest testing uses the temporary standard-web-global compatibility shim described in the previous entry/mailbox review. CI and the backend image remain pinned to Node 22. HTTP tests were allowed to bind localhost.

The automated tests use controlled provider responses and database fixtures. They do not certify live provider permissions, a real database outage drill, or signed-device performance. Worker readiness is for the workers hosted inside each API process, not a remote worker fleet. Cooperative cancellation cannot undo an external action already sent to a provider. Mutations are not automatically retried merely because the client timed out; existing idempotency keys and explicit status checks protect recovery.

## Deployment

1. Build/deploy the backend and restart it so the updated candidate API, search predicates, counts, and workers are running.
2. Rebuild/restart the Flutter application. The HTTP dependency minimum now declares the abortable-request API used by the implementation; the existing lockfile already resolves a compatible version.
3. Monitor readiness for the additional background components and verify a two-mailbox login, remote subscription search, and representative cleanup/unsubscribe operations in staging before releasing to users.
