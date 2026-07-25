# SenderWho on a Hostinger VPS

This Docker package requires a Hostinger **VPS** with SSH/root access. The API
now uses MySQL-backed jobs and does not require Redis. For Business Web Hosting,
use the separate shared-hosting release instead of this Docker stack.

## 1. Prepare DNS

Create an A record for `api.yourdomain.com` pointing to the VPS IPv4 address.
Wait until `dig +short api.yourdomain.com` returns that address.

## 2. Prepare the VPS

Use Hostinger's Ubuntu 24.04 Docker VPS template. Add an SSH key in hPanel and
configure the Hostinger firewall to allow TCP 22, 80, and 443 only. Do not open
3000, 3306, or 6379.

Upload and extract the release under `/opt/senderwho`, then run:

```bash
cd /opt/senderwho
cp deploy/hostinger/.env.hostinger.example .env.hostinger
chmod 600 .env.hostinger
```

Generate independent secrets and paste them into `.env.hostinger`:

```bash
openssl rand -hex 32
openssl rand -hex 32
openssl rand -hex 32
openssl rand -hex 64
openssl rand -base64 32
```

Set `API_DOMAIN`, Google OAuth client ID/secret, and a new immutable image tag.

## 3. Configure Google

In the Google Cloud Web OAuth client, add this exact authorized redirect URI:

```text
https://api.yourdomain.com/api/v1/auth/oauth/google/callback
```

The value must exactly match `API_DOMAIN` in `.env.hostinger`.

## 4. Deploy

```bash
docker compose --env-file .env.hostinger -f docker-compose.hostinger.yml config
docker compose --env-file .env.hostinger -f docker-compose.hostinger.yml up --build -d
docker compose --env-file .env.hostinger -f docker-compose.hostinger.yml ps
docker compose --env-file .env.hostinger -f docker-compose.hostinger.yml logs --tail=100 api caddy
```

Caddy obtains and renews the HTTPS certificate automatically after DNS points to
the VPS and ports 80/443 are reachable. Prisma migrations run before the API.
MySQL has no public port.

Check:

```bash
curl https://api.yourdomain.com/api/v1/health/live
curl https://api.yourdomain.com/api/v1/health/ready
```

## 5. Build the Flutter app against production

From the `senderwho` directory on the Mac used for iOS builds:

```bash
flutter build ipa --release \
  --dart-define=SENDERWHO_API_URL=https://api.yourdomain.com/api/v1
```

Do not use the local HTTP URL in a release build.

## 6. Backups and updates

Make the backup script executable and test it:

```bash
chmod 700 deploy/hostinger/backup.sh
./deploy/hostinger/backup.sh
```

Copy encrypted backups off the VPS. A backup only on the same VPS is not a
disaster-recovery backup. Test a restore before launch.

For an update, upload a new release, change `SENDERWHO_IMAGE_TAG`, and repeat the
deployment commands. Never delete Docker volumes during a normal update.

## Important exclusions

The release archive intentionally excludes real `.env` files, database data,
OAuth tokens, node modules, build output, logs, backups, and Git metadata. Create
new production secrets; never copy development secrets or the local database to
production unless a reviewed data migration explicitly requires it.
