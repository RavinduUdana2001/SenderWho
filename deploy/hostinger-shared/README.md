# SenderWho on Hostinger Business Web Hosting

This release runs NestJS, Gmail workers, retries, progress, deduplication, and
API rate limiting with Hostinger MySQL. It does not require Redis or Docker.

## 1. Create MySQL

In hPanel, open `Databases -> MySQL Databases`, create a database and user, and
save the database name, username, password, and host. The host must be
`localhost` for this deployment mode.

Use URL-safe characters in the password, or percent-encode it when constructing
`DATABASE_URL`:

```text
mysql://DB_USER:ENCODED_PASSWORD@localhost:3306/DB_NAME
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

`main.js` runs `prisma migrate deploy` safely before starting the
API, so the schema is upgraded on each release without manual phpMyAdmin SQL.

## 3. Add environment variables

Copy every key from `.env.hostinger-shared.example` into hPanel's Environment
Variables section, replace placeholders, and do not upload a real `.env` file.
Do not manually set `PORT`; Hostinger supplies it to the application.

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
