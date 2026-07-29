# SenderWho on Hostinger Business Web Hosting

This release runs NestJS, Gmail workers, retries, progress, deduplication, and
API rate limiting with Hostinger MySQL. It does not require Redis or Docker.

## 1. Create MySQL

In hPanel, open `Databases -> MySQL Databases`, create a database and user, and
save the database name, username, password, and host. Use these separate hPanel
environment variables so passwords containing special characters are handled
safely:

```text
DB_HOST=localhost
DB_PORT=3306
DB_USER=your Hostinger database user
DB_PASSWORD=your exact Hostinger database password
DB_NAME=your Hostinger database name
DB_CONNECTION_LIMIT=5
```

## 2. Create the Node.js application

In hPanel, select `Websites -> Add Website -> Deploy Web App -> Upload ZIP` and
upload the shared-hosting release ZIP.

Use these settings:

```text
Framework: NestJS (or Other)
Node.js: 22
Build command: npm run build
Output directory: dist
Entry file: main.js
```

`main.js` takes a MySQL advisory lock and applies packaged migrations before
opening the HTTP listener, so the schema is upgraded safely on each release
without manual phpMyAdmin SQL. The runtime uses Prisma's JavaScript MariaDB
adapter to avoid native query-engine crashes on shared hosting.

## 3. Add environment variables

Copy every key from `.env.hostinger-shared.example` into hPanel's Environment
Variables section, replace placeholders, and do not upload a real `.env` file.
Do not manually set `PORT`; Hostinger supplies it to the application.
Set `PUBLIC_LEGAL_NAME` to the owner/company name and
`PUBLIC_SUPPORT_EMAIL` to a real monitored support address. These values are
shown on the public privacy, terms, support, and account-deletion pages.

Generate secrets locally:

```bash
openssl rand -hex 64
openssl rand -base64 32
```

## 4. Domain and Google OAuth

Connect `senderwho.com` to the Node.js application in hPanel. After SSL is
active, add this exact redirect URI to the Google Cloud Web OAuth client:

```text
https://senderwho.com/api/v1/auth/oauth/google/callback
```

Update the domain in `CORS_ORIGINS` and `GOOGLE_OAUTH_CALLBACK_URL`, then
restart/redeploy the application.

## 5. Verify

Open:

```text
https://senderwho.com/
https://senderwho.com/privacy
https://senderwho.com/terms
https://senderwho.com/support
https://senderwho.com/delete-account
https://senderwho.com/api/v1/health/live
https://senderwho.com/api/v1/health/ready
```

The ready response must show both `mysql` and `databaseQueue` as `up`. Then log
in with a test Gmail account and verify scan, cleanup, and one-click unsubscribe
progress before releasing the Flutter production build.

## Operational limits

MySQL jobs are intentionally processed in bounded batches and use leases,
deduplication, retry backoff, and restart recovery. Business shared hosting is
appropriate for an initial launch. Monitor hPanel CPU/memory/runtime logs and
move the unchanged API contract to a VPS if sustained background volume exceeds
the shared plan's limits.
