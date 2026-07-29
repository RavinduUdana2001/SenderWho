# Hostinger Business Web Hosting deployment

1. In hPanel, create a MySQL database and user under `Databases -> MySQL
   Databases`. Keep the host as `localhost`.
2. Open `Websites -> Add Website -> Deploy Web App -> Upload ZIP` and upload
   this archive.
3. Select Node.js 22 and NestJS (or Other).
4. Use `npm run build`, output directory `dist`, and entry file
   `main.js`.
5. Add `DB_HOST=localhost`, `DB_PORT=3306`, your exact `DB_USER`,
   `DB_PASSWORD`, and `DB_NAME`, plus `DB_CONNECTION_LIMIT=5`. Copy the
   remaining keys from `.env.hostinger-shared.example` into hPanel Environment
   Variables. Set `PUBLIC_LEGAL_NAME` to the owner/company name and
   `PUBLIC_SUPPORT_EMAIL` to a real monitored address. Replace every
   placeholder and do not set `PORT` manually.
6. Connect `senderwho.com` in the application dashboard and wait for SSL.
7. Add the exact Google OAuth redirect URI
   `https://senderwho.com/api/v1/auth/oauth/google/callback`.
8. Leave `YAHOO_OAUTH_ENABLED=false` until Yahoo has approved `mail-r` and
   `mail-w`. This keeps Yahoo hidden without affecting Gmail. After approval,
   add the Yahoo Client ID, rotated Client Secret, exact callback URL, and set
   the flag to `true`.
9. Redeploy, then verify `/`, `/privacy`, `/terms`, `/support`,
   `/delete-account`, `/api/v1/health/live`, `/api/v1/health/ready`, and
   `/api/v1/auth/providers`.

`main.js` applies committed Prisma migrations before starting the API. This
release uses Prisma's JavaScript MariaDB adapter, avoiding the native query
engine timer panic on shared hosting. The ready endpoint must show `mysql` and
`databaseQueue` as `up`. MySQL provides durable jobs and API throttling; Redis
is not required.
