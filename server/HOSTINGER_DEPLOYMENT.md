# Hostinger Business Web Hosting deployment

1. In hPanel, create a MySQL database and user under `Databases -> MySQL
   Databases`. Keep the host as `localhost`.
2. Open `Websites -> Add Website -> Deploy Web App -> Upload ZIP` and upload
   this archive.
3. Select Node.js 22 and NestJS (or Other).
4. Use `npm run build`, output directory `dist`, and entry file
   `main.js`.
5. Copy the keys from `.env.hostinger-shared.example` into hPanel Environment
   Variables. Replace every placeholder and do not set `PORT` manually.
6. Connect `api.yourdomain.com` in the application dashboard and wait for SSL.
7. Add the exact Google OAuth redirect URI
   `https://api.yourdomain.com/api/v1/auth/oauth/google/callback`.
8. Leave `YAHOO_OAUTH_ENABLED=false` until Yahoo has approved `mail-r` and
   `mail-w`. This keeps Yahoo hidden without affecting Gmail. After approval,
   add the Yahoo Client ID, rotated Client Secret, exact callback URL, and set
   the flag to `true`.
9. Redeploy, then verify `/api/v1/health/live`, `/api/v1/health/ready`, and
   `/api/v1/auth/providers`.

`main.js` applies committed Prisma migrations before starting the
API. The ready endpoint must show `mysql` and `databaseQueue` as `up`. This
release uses MySQL for durable jobs and API throttling; Redis is not required.
