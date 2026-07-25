# SenderWho Production Architecture

This document is the recommended production blueprint for SenderWho: a Flutter mobile app that connects to a user's email account, identifies real senders, flags risky messages, organizes senders, supports unsubscribe/cleanup flows, and keeps user privacy central.

## Executive Recommendation

Use this stack for a production-ready version:

```text
Mobile app:        Flutter
App architecture:  Feature-first clean architecture
State management:  Riverpod
Routing:           go_router

Backend:           Node.js + TypeScript
Framework:         NestJS
Database:          MySQL 8 selected for this project
ORM:               Prisma
Queue:             Redis + BullMQ
Email providers:   Gmail API, Microsoft Graph, Yahoo/IMAP fallback
Auth:              OAuth 2.0 + app JWT/session
Hosting:           Railway/Render/Fly.io for MVP, AWS/GCP for scale
Monitoring:        Sentry + structured logs + uptime checks
```

The selected backend choice for this app is **NestJS + TypeScript + Prisma + MySQL 8 + Redis/BullMQ**.

MySQL 8 is a good fit for SenderWho because the app has clear relational data: users, connected accounts, senders, messages, alerts, cleanup jobs, unsubscribe jobs, and audit logs. Prisma keeps database access type-safe and leaves room to switch databases later if the product ever needs it.

## Why This Architecture Fits SenderWho

SenderWho is not just a simple CRUD app. It needs secure OAuth, background inbox scanning, sender scoring, cleanup jobs, unsubscribe jobs, alerts, connected accounts, privacy controls, and eventually notifications. Those are asynchronous and security-sensitive workflows.

Node.js + TypeScript is a strong fit because email API work is I/O-heavy. NestJS gives the backend a clean module/service/controller architecture instead of becoming a loose pile of Express routes. Prisma gives type-safe DB access and supports PostgreSQL and MySQL. BullMQ with Redis is ideal for long-running inbox scan and cleanup jobs.

## High-Level System Design

```text
Flutter App
  |
  | HTTPS JSON API
  v
NestJS API Server
  |
  |-- Auth Module
  |-- Email Accounts Module
  |-- Sender Analysis Module
  |-- Security Alerts Module
  |-- Cleanup Module
  |-- Unsubscribe Module
  |-- Settings Module
  |
  | Prisma ORM
  v
MySQL 8

NestJS API Server
  |
  | Add jobs
  v
Redis + BullMQ
  |
  | Background workers
  v
Email Provider APIs
  |-- Gmail API
  |-- Microsoft Graph
  |-- Yahoo/IMAP fallback
```

## Frontend Architecture

The current Flutter UI is fine for prototype/demo stage. For production, refactor into a feature-first structure.

Recommended Flutter structure:

```text
lib/
  main.dart

  app/
    app.dart
    router.dart
    bootstrap.dart
    theme/
      app_colors.dart
      app_theme.dart
      app_text_styles.dart
    config/
      app_config.dart

  core/
    api/
      api_client.dart
      api_exception.dart
    auth/
      session_store.dart
      auth_interceptor.dart
    storage/
      secure_storage_service.dart
    widgets/
      app_button.dart
      app_card.dart
      app_header.dart
      app_page.dart
    utils/
      responsive.dart

  features/
    onboarding/
      presentation/
        screens/
        widgets/

    auth/
      data/
        auth_api.dart
        auth_repository_impl.dart
      domain/
        auth_repository.dart
        auth_session.dart
      presentation/
        screens/
        providers/
        widgets/

    dashboard/
      data/
      domain/
      presentation/

    senders/
      data/
      domain/
      presentation/

    inbox_health/
      data/
      domain/
      presentation/

    security_alerts/
      data/
      domain/
      presentation/

    cleanup/
      data/
      domain/
      presentation/

    unsubscribe/
      data/
      domain/
      presentation/

    settings/
      data/
      domain/
      presentation/
```

Recommended Flutter packages:

```yaml
go_router: routing
flutter_riverpod: state management
dio: HTTP client
flutter_secure_storage: token storage
freezed: immutable models
json_serializable: JSON mapping
intl: dates/numbers
sentry_flutter: crash reporting
```

Frontend production rules:

- Do not call Gmail/Microsoft APIs directly from Flutter except for provider-approved OAuth handoff flows.
- Store only app access/session tokens on device.
- Store OAuth refresh tokens only on backend, encrypted.
- Use Riverpod providers per feature, not global mutable state.
- Use go_router instead of large `routes` maps in `main.dart`.
- Keep UI widgets dumb; business logic belongs in repositories/providers.

## Backend Architecture

Recommended backend folder structure:

```text
server/
  src/
    main.ts
    app.module.ts

    common/
      config/
      decorators/
      filters/
      guards/
      interceptors/
      logger/
      pipes/
      utils/

    database/
      prisma.module.ts
      prisma.service.ts

    auth/
      auth.module.ts
      auth.controller.ts
      auth.service.ts
      jwt.strategy.ts
      oauth.service.ts

    users/
      users.module.ts
      users.controller.ts
      users.service.ts

    email-accounts/
      email-accounts.module.ts
      email-accounts.controller.ts
      email-accounts.service.ts
      token-vault.service.ts

    providers/
      gmail/
        gmail.client.ts
        gmail.mapper.ts
      microsoft/
        microsoft-graph.client.ts
      imap/
        imap.client.ts

    senders/
      senders.module.ts
      senders.controller.ts
      senders.service.ts
      sender-scoring.service.ts

    inbox-health/
      inbox-health.module.ts
      inbox-health.service.ts

    security-alerts/
      security-alerts.module.ts
      security-alerts.controller.ts
      security-alerts.service.ts

    cleanup/
      cleanup.module.ts
      cleanup.controller.ts
      cleanup.service.ts

    unsubscribe/
      unsubscribe.module.ts
      unsubscribe.controller.ts
      unsubscribe.service.ts

    jobs/
      queues.module.ts
      scan-inbox.processor.ts
      cleanup.processor.ts
      unsubscribe.processor.ts
      token-refresh.processor.ts

    notifications/
      notifications.module.ts

  prisma/
    schema.prisma
    migrations/

  test/
```

## Database Choice

### MySQL 8 Selected

Use MySQL 8 for SenderWho.

Why:

- Strong relational model.
- Mature managed hosting options.
- Good fit for users, connected accounts, senders, messages, jobs, and audit logs.
- Works well with Prisma.
- Easier if your current database experience is MySQL.

Production rules:

- Use InnoDB.
- Use managed MySQL with automatic backups.
- Index `userId`, `emailAccountId`, provider IDs, sender emails, domains, risk levels, and date columns.
- Use JSON columns only for provider-specific metadata, labels, flags, and job metadata.
- Keep normalized relational tables for core product data.
- Avoid storing full email body content.

### Final Recommendation

```text
Selected now: MySQL 8
Also strong:  PostgreSQL
Avoid core:   MongoDB-only design
```

MongoDB is not my first choice because this app has clear relational entities: users, accounts, senders, messages, alerts, cleanup jobs, and audit logs.

## Core Data Model

Suggested entities:

```text
users
  id
  email
  display_name
  avatar_url
  created_at
  updated_at
  deleted_at

email_accounts
  id
  user_id
  provider
  provider_account_id
  email_address
  display_name
  access_token_encrypted
  refresh_token_encrypted
  token_expires_at
  scopes
  sync_status
  last_synced_at
  created_at
  updated_at

senders
  id
  user_id
  email_account_id
  name
  email
  domain
  category
  trust_score
  risk_level
  first_seen_at
  last_seen_at
  total_messages
  unread_messages
  is_blocked
  is_trusted
  created_at
  updated_at

messages
  id
  user_id
  email_account_id
  sender_id
  provider_message_id
  thread_id
  subject
  snippet
  received_at
  is_read
  labels
  risk_flags
  size_bytes
  created_at

security_alerts
  id
  user_id
  email_account_id
  sender_id
  message_id
  title
  reason
  risk_level
  status
  detected_at
  resolved_at

cleanup_suggestions
  id
  user_id
  email_account_id
  category
  message_count
  estimated_space_bytes
  status
  created_at

cleanup_jobs
  id
  user_id
  email_account_id
  status
  total_messages
  processed_messages
  failed_messages
  started_at
  completed_at

unsubscribe_jobs
  id
  user_id
  sender_id
  status
  method
  unsubscribe_url
  created_at
  completed_at

audit_logs
  id
  user_id
  action
  target_type
  target_id
  metadata
  ip_address
  created_at
```

Important privacy rule: avoid storing full email body content unless absolutely required. Store only metadata/snippets needed for the product.

## API Design

Use versioned REST first:

```text
/api/v1/auth/*
/api/v1/email-accounts/*
/api/v1/dashboard/*
/api/v1/senders/*
/api/v1/inbox-health/*
/api/v1/security-alerts/*
/api/v1/cleanup/*
/api/v1/unsubscribe/*
/api/v1/settings/*
```

Example endpoints:

```text
POST   /api/v1/auth/oauth/google/start
GET    /api/v1/auth/oauth/google/callback
POST   /api/v1/auth/logout

GET    /api/v1/email-accounts
DELETE /api/v1/email-accounts/:id
POST   /api/v1/email-accounts/:id/sync

GET    /api/v1/dashboard
GET    /api/v1/inbox-health

GET    /api/v1/senders
GET    /api/v1/senders/:id
POST   /api/v1/senders/:id/block
POST   /api/v1/senders/:id/trust

GET    /api/v1/security-alerts
GET    /api/v1/security-alerts/:id
POST   /api/v1/security-alerts/:id/resolve

GET    /api/v1/cleanup/suggestions
POST   /api/v1/cleanup/jobs
GET    /api/v1/cleanup/jobs/:id

POST   /api/v1/unsubscribe/jobs
GET    /api/v1/unsubscribe/jobs/:id

GET    /api/v1/settings
PATCH  /api/v1/settings
```

## Email Provider Strategy

Priority order:

```text
1. Gmail API
2. Microsoft Graph for Outlook/Office 365
3. Yahoo/IMAP fallback only where provider APIs are not enough
```

Gmail:

- Use OAuth 2.0.
- Request the minimum scopes needed.
- Prefer metadata/list APIs where possible.
- Avoid downloading full bodies unless required.

Microsoft:

- Use Microsoft Graph Mail APIs.
- Same rule: minimal permissions, metadata-first design.

IMAP fallback:

- Use only when official APIs are unavailable.
- More difficult to secure and normalize.
- Should be isolated behind a provider adapter.

## Background Jobs

Use BullMQ + Redis for jobs:

```text
scan-inbox
refresh-oauth-token
calculate-sender-score
generate-cleanup-suggestions
bulk-delete-messages
unsubscribe-from-sender
send-notification
```

Why jobs matter:

- Inbox scanning can take time.
- APIs have rate limits.
- Deleting many emails should not block the mobile app.
- Failed jobs need retry logic.
- Users need progress status.

Every job should be idempotent. Running the same job twice should not corrupt data.

## Sender Scoring Model

Start simple and transparent.

Score inputs:

```text
domain_age_signal
domain_mismatch_signal
spf_dkim_dmarc_signal
known_provider_signal
unsubscribe_rate_signal
message_frequency_signal
user_history_signal
blocked_sender_signal
trusted_sender_signal
spam_keyword_signal
```

Initial score buckets:

```text
90-100 Excellent / trusted
70-89  Good
50-69  Medium risk
0-49   High risk
```

Do not market this as perfect fraud detection. Treat it as a risk signal and explain reasons to the user.

## Security Requirements

This app handles sensitive email metadata, so security is not optional.

Must-have:

- HTTPS everywhere.
- OAuth refresh tokens encrypted at rest.
- Never log access tokens or refresh tokens.
- JWT/session expiry and refresh flow.
- Rate limiting.
- Request validation.
- Audit logs for destructive actions.
- Soft-delete user data before permanent delete.
- Principle of least privilege for OAuth scopes.
- Separate production/staging/dev secrets.
- Database backups.
- Admin access restricted by role.

Recommended token storage:

```text
Flutter:
  short-lived app session token in flutter_secure_storage

Backend:
  encrypted OAuth refresh token in DB
  encryption key in cloud secret manager
```

## Privacy Rules

SenderWho should be privacy-first.

Product promise:

```text
We analyze email metadata to help identify senders and clean inboxes.
We avoid storing full email content unless required for a user-requested action.
```

Rules:

- Store snippets, sender info, labels, timestamps, and message IDs.
- Avoid storing full body content.
- Let users disconnect accounts.
- Let users delete all account data.
- Keep audit logs for security, but avoid sensitive content in logs.
- Make cleanup actions explicit and confirm destructive operations.

## Deployment Plan

### MVP Deployment

Good MVP setup:

```text
Flutter app:       iOS TestFlight + Android internal testing
Backend:           Railway / Render / Fly.io
Database:          Managed MySQL
Redis:             Managed Redis
File storage:      Not needed initially
Monitoring:        Sentry
Logs:              Provider logs + JSON app logs
```

### Production Deployment

Scale setup:

```text
Backend API:       AWS ECS/Fargate, Google Cloud Run, or Fly.io Machines
Workers:           Separate worker service
Database:          Managed MySQL with backups
Redis:             Managed Redis
Secrets:           AWS Secrets Manager / GCP Secret Manager
Monitoring:        Sentry + OpenTelemetry + uptime monitor
CI/CD:             GitHub Actions
```

Separate API and worker processes:

```text
api-service
worker-service
scheduled-jobs-service
```

Do not run heavy inbox scans inside the request/response API process.

## Environment Variables

Example backend environment:

```text
NODE_ENV=production
PORT=3000
DATABASE_URL=mysql://...
REDIS_URL=redis://...
JWT_SECRET=...
JWT_EXPIRES_IN=15m
REFRESH_TOKEN_SECRET=...
TOKEN_ENCRYPTION_KEY=...

GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
GOOGLE_OAUTH_CALLBACK_URL=...

MICROSOFT_CLIENT_ID=...
MICROSOFT_CLIENT_SECRET=...
MICROSOFT_OAUTH_CALLBACK_URL=...

SENTRY_DSN=...
```

## Testing Strategy

Flutter:

```text
unit tests for providers/repositories
widget tests for screens
golden tests for key Figma screens later
integration tests for main flows
```

Backend:

```text
unit tests for services
integration tests for repositories
e2e tests for API endpoints
mock provider APIs for Gmail/Microsoft
queue job tests
security tests for auth guards
```

Important flows to test:

```text
connect Gmail
sync inbox
view dashboard
view sender details
block sender
create cleanup job
unsubscribe job
disconnect account
delete account
expired OAuth token refresh
provider API failure
```

## Recommended Build Roadmap

### Phase 1: UI + Local Mock Data

Current project is here.

- Finish Figma UI match.
- Add responsive tests.
- Keep sample data.
- No backend yet.

### Phase 2: Backend Foundation

- Create NestJS backend.
- Add Prisma.
- Add MySQL schema.
- Add auth module.
- Add basic users and sessions.
- Add health check endpoint.

### Phase 3: OAuth + Connected Accounts

- Google OAuth.
- Store encrypted refresh tokens.
- Connected accounts API.
- Flutter connect email flow calls backend.

### Phase 4: Inbox Sync

- Gmail message list sync.
- Store message metadata.
- Store senders.
- Add background scan job.
- Dashboard API uses real data.

### Phase 5: Sender Intelligence

- Sender score calculation.
- Security alerts.
- Inbox health.
- Categories.
- Sender details.

### Phase 6: Cleanup + Unsubscribe

- Cleanup suggestions.
- Bulk delete jobs.
- Unsubscribe detection.
- Confirmation flows.
- Job progress endpoints.

### Phase 7: Production Hardening

- Monitoring.
- Backups.
- Rate limits.
- Audit logs.
- Privacy/delete-account workflow.
- App Store / Play Store release setup.

## Suggested Monorepo Layout

When backend starts, use this project layout:

```text
SenderWho/
  senderwho/
    lib/
    pubspec.yaml

  server/
    src/
    prisma/
    package.json

  docs/
    production_architecture.md
    api_contract.md
    database_schema.md

  docker-compose.yml
  README.md
```

The Flutter app lives in `senderwho/` and the backend lives in `server/`. This keeps mobile and backend code separate while still keeping the product in one project folder.

## Final Decision

Use this production stack:

```text
Flutter + Riverpod + go_router
NestJS + TypeScript
Prisma
MySQL 8
Redis + BullMQ
Gmail API + Microsoft Graph + IMAP fallback
Sentry + structured logs
```

This gives SenderWho a clean path from prototype to production without overengineering too early.

## Reference Links

- NestJS documentation: https://docs.nestjs.com/
- Prisma documentation: https://www.prisma.io/docs
- BullMQ documentation: https://docs.bullmq.io/
- Gmail API documentation: https://developers.google.com/workspace/gmail/api/guides
- Microsoft Graph Outlook Mail overview: https://learn.microsoft.com/en-us/graph/outlook-mail-concept-overview
- MySQL documentation: https://dev.mysql.com/doc/
- PostgreSQL documentation: https://www.postgresql.org/docs/
- Riverpod package: https://pub.dev/packages/flutter_riverpod
