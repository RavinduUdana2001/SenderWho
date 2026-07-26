# SenderWho Server

Production-oriented Node.js backend for SenderWho.

## Stack

```text
Node.js + TypeScript
NestJS
Prisma
MySQL 8
MySQL-backed durable background jobs
OAuth 2.0 provider integrations
```

## Local Setup

From the repository root:

```bash
docker compose up -d mysql
cd server
cp .env.example .env
npm install
npm run dev
```

`npm run dev` now generates Prisma Client and applies every committed migration
before NestJS enters watch mode. This prevents code/schema mismatches such as a
new OAuth session field being present in TypeScript but missing from local
MySQL. `npm run start:dev` performs the same preflight. Production still uses
the separate one-shot migration job described below.

Generate production-safe local secrets before starting the API:

```bash
openssl rand -base64 32
openssl rand -hex 32
```

Put the Base64 value in `TOKEN_ENCRYPTION_KEY` and the hex value in
`JWT_SECRET`. Keep `MOCK_DATA_ENABLED=false` whenever you want real Gmail and
MySQL data.

## MySQL and Prisma

The repository already contains the MySQL schema and all required versioned
migrations under `prisma/migrations/`.

For the included Docker database, apply and verify them with:

```bash
docker compose up -d mysql redis
cd server
npm run prisma:generate
npm run prisma:deploy
npx prisma migrate status
```

Use `prisma migrate deploy` outside development. It applies committed
migrations without trying to redesign the production database. The local
connection string is:

```text
mysql://senderwho:senderwho_password@localhost:3307/senderwho
```

### Production migration job

The production Dockerfile has separate `runtime` and `migration` targets. The
long-running API image contains only production dependencies. The one-shot
migration image contains the Prisma CLI, runs as the unprivileged `node` user,
and defaults to `prisma migrate deploy`.

Provision two untracked environment files from the committed examples:

- `server/.env.production` contains the complete API runtime configuration.
- `server/.env.migration.production` contains only `DATABASE_URL`. On the
  Hostinger VPS, keep this untracked file root-owned with mode `600` and use
  certificate-validated TLS. Never bake it into an image or commit it.

Then deploy with an immutable image tag:

```bash
SENDERWHO_IMAGE_TAG=<immutable-release-tag> \
  docker compose -f docker-compose.production.yml up --build -d
```

Compose starts the API only after the migration container exits successfully.
If an orchestrator runs jobs separately, build the `migration` target, run it to
completion before rolling out the `runtime` target, and use a database identity
that can apply migrations but is not shared with the API runtime.

### See the database

The easiest local visual browser is Adminer. From the repository root run:

```bash
docker compose --profile tools up -d mysql adminer
```

Open `http://localhost:8080` and use:

```text
System:   MySQL
Server:   mysql
Username: senderwho
Password: senderwho_password
Database: senderwho
```

Adminer is bound to `127.0.0.1`, so it is only reachable on your computer. Do
not deploy this local tool publicly. Useful tables are `User`, `EmailAccount`,
`Sender`, `Message`, `CleanupSuggestion`, `CleanupJob`, `UnsubscribeJob`,
`AppSession`, and `UserSettings`. OAuth tokens in `EmailAccount` are encrypted;
never copy them into logs or edit them manually.

Prisma Studio is another option:

```bash
cd server
npm run prisma:studio
```

It prints a local URL, normally `http://localhost:5555`. To inspect from the
terminal instead:

```bash
docker compose exec mysql mysql -usenderwho -psenderwho_password senderwho
```

Inside MySQL, try `SHOW TABLES;`, `SELECT COUNT(*) FROM Message;`, and
`SELECT emailAddress, syncStatus, lastSyncedAt, lastSyncError FROM EmailAccount;`.

Create a local backup from the repository root with:

```bash
docker compose exec -T mysql mysqldump -usenderwho -psenderwho_password senderwho > senderwho-backup.sql
```

For hosted MySQL, create a database/user, replace `DATABASE_URL`, require TLS as
supported by the provider, and run `npm run prisma:deploy` from the release
job. Do not use the sample Docker password in production.

## Gmail OAuth and first scan

In Google Cloud Console, enable the Gmail API, configure the OAuth consent
screen, and create a Web OAuth client with this exact local redirect URI:

```text
http://localhost:3000/api/v1/auth/oauth/google/callback
```

Set `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and
`GOOGLE_OAUTH_CALLBACK_URL` in `.env`. SenderWho requests `gmail.modify` so it
can read metadata and perform user-requested archive/trash actions. Google may
require OAuth verification before non-test users can grant this sensitive
scope.

The Flutter app creates a short-lived OAuth login transaction, opens Google in
the system browser, and polls the transaction using a high-entropy secret that
is never put in the browser URL. After the callback, the API encrypts Google's
access/refresh tokens, persists the account as `PENDING`, and queues the durable
MySQL-backed first scan. The worker changes it to `SYNCING`, downloads Gmail metadata (not
message bodies), upserts senders and messages, calculates cleanup suggestions,
and finally writes `READY`. A failed scan stores `FAILED` plus `lastSyncError`;
the Connected Accounts screen provides an explicit **Scan now** retry.

When the OAuth transaction is exchanged, the app receives a 15-minute access
JWT and a one-time rotating refresh token. Only the refresh token is stored in
iOS Keychain/Android Keystore. Every data and mutation endpoint requires the
access JWT and scopes its query to that user's ID. Expired Google access tokens
are refreshed server-side and encrypted again before Gmail API work continues.

The app refresh session uses a 365-day sliding expiry. Each valid refresh rotates
the token atomically, revokes the previous token, and issues a new 365-day token.
Normal app restarts therefore restore the session without opening Google again.
**Sign out** revokes only the current SenderWho app session; it intentionally
keeps the encrypted Gmail connection so a returning user can select their Google
account without being forced through consent again. **Disconnect Gmail** is the
separate destructive action that revokes provider access and stops future scans.
Google can still require consent for a first connection, changed scopes, a
revoked grant, or a replaced OAuth client.

Useful checks:

```bash
curl http://localhost:3000/api/v1/health
```

### Gmail reports `disabled_client`

This response comes from Google before Gmail can be accessed. Open the Google
Cloud project used by `GOOGLE_CLIENT_ID`, go to **Google Auth Platform >
Clients**, and enable the matching OAuth client/client secret. If the original
credential cannot be enabled, create a replacement web OAuth client and update
both `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` together. Keep this callback
URI registered exactly:

```text
http://localhost:3000/api/v1/auth/oauth/google/callback
```

Restart the API after changing `.env`, then reconnect Gmail in SenderWho so a
new refresh token is issued. Repeatedly pressing **Scan now** cannot repair a
disabled Google credential.

### Google Cloud setup checklist

Use a separate Google Cloud project for local development, staging, and
production. For the local development project:

1. Open **APIs & Services > Library**, find **Gmail API**, and enable it.
2. Open **Google Auth Platform > Branding**. Set the app name to SenderWho,
   choose a support email, and keep the developer contact email current.
3. Open **Google Auth Platform > Audience**. Use **External > Testing** during
   development and add every Gmail account that will test the app. A Testing
   authorization that includes Gmail scopes expires after seven days, so this
   mode cannot provide a production-length Gmail connection.
4. Open **Google Auth Platform > Data Access** and declare only the scopes the
   server currently requests: `openid`, `userinfo.email`, and `gmail.modify`.
5. Open **Google Auth Platform > Clients**, choose **Create client**, and select
   **Web application**. The secret belongs on the backend; never put it in the
   Flutter application.
6. Add this exact authorized redirect URI, including scheme, port, path, and no
   trailing slash:

   ```text
   http://localhost:3000/api/v1/auth/oauth/google/callback
   ```

7. Copy the new client ID and client secret into `server/.env` together:

   ```dotenv
   GOOGLE_CLIENT_ID=your-new-client-id.apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET=your-new-client-secret
   GOOGLE_OAUTH_CALLBACK_URL=http://localhost:3000/api/v1/auth/oauth/google/callback
   ```

8. Rebuild and restart the API, then reconnect Gmail once. Tokens issued to an
   old OAuth client cannot be migrated to a replacement client.

For production, replace localhost with an HTTPS API domain that you control,
register that exact production callback, store the secret in a managed secret
manager, and submit the Branding and Data Access configuration for verification.
`gmail.modify` is a restricted Gmail scope. A public SenderWho deployment must
complete Google's restricted-scope review and may need a recurring security
assessment because the backend stores or processes Gmail-derived data.

`email-accounts`, `dashboard`, sender, message, cleanup, unsubscribe, settings,
and alert endpoints intentionally return `401` without the app access token.
Use Swagger's **Authorize** button with a current access JWT when debugging an
authenticated endpoint; do not paste a refresh token into Swagger.

Local ports:

```text
NestJS API: http://localhost:3000/api/v1
MySQL:      localhost:3307
Adminer:    http://localhost:8080 (only with the tools profile)
```

The Docker MySQL port is `3307` so it does not conflict with a native MySQL
installation on the standard `3306` port.

For an Android emulator, expose the host API through ADB before running the
Flutter application:

```bash
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 reverse tcp:3000 tcp:3000
cd ../senderwho
flutter run -d emulator-5554
```

Flutter reads the API address from `lib/config/app_config.dart`. Override it
for another environment without editing source code:

```bash
flutter run --dart-define=SENDERWHO_API_URL=https://api.example.com/api/v1
```

If TypeScript imports such as `@nestjs/common` or `@prisma/client` appear red in the IDE, run `npm install` inside `server/`. Those errors mean Node dependencies are missing, not that the server source files are in the wrong folder.

API health check:

```text
GET http://localhost:3000/api/v1/health
```

Swagger docs:

```text
http://localhost:3000/api/v1/docs
```

## Production Notes

- OAuth access and refresh tokens are encrypted with AES-256-GCM using
  `TOKEN_ENCRYPTION_KEY`.
- Full email body content is not downloaded or stored.
- App refresh tokens are random, hashed in MySQL, rotated on every use, and
  revocable on logout. Their sliding expiry is 365 days by default; access JWTs
  expire after 15 minutes by default.
- All non-public API endpoints require authentication and enforce per-user
  ownership before reads or Gmail mutations.
- Run with `MOCK_DATA_ENABLED=false`; demo fallbacks are explicitly limited to
  mock mode.
- The local process hosts the API and database-job processors together. Move to
  dedicated workers or a VPS before high-volume production use.
- Use managed MySQL with automated backups.
- Put secrets in a secret manager, not `.env` files.
- In production, use HTTPS for the API and Google callback, set an explicit
  `CORS_ORIGINS`, rotate secrets, restrict database network access, and enable
  automated encrypted backups.
