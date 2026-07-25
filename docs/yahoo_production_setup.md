# Yahoo Mail production setup

SenderWho connects Yahoo Mail through IMAP over TLS using a Yahoo-generated app
password. Do not request the user's normal Yahoo password. Yahoo OAuth developer
keys are not required for this connection method.

## 1. Prepare the Yahoo account

1. Sign in to the client's Yahoo account in a normal browser window.
2. Open **Yahoo Account Security**.
3. Under **External connections**, choose **Create app password**.
4. Use `SenderWho` as the app name.
5. Copy the generated app password. It is shown only for setup.
6. Do not place this password in a source file, `.env`, message, screenshot, or
   deployment log.

If Yahoo does not offer the app-password option, use a browser that has been
used with the account for several days and ensure account recovery/verification
prompts are complete. Yahoo states that support cannot override app-password
eligibility.

## 2. Deploy the backend

Production environment:

```env
YAHOO_IMAP_HOST=imap.mail.yahoo.com
YAHOO_IMAP_PORT=993
```

No `YAHOO_CLIENT_ID` or `YAHOO_CLIENT_SECRET` is needed for IMAP app-password
setup. Keep the existing `TOKEN_ENCRYPTION_KEYS` and
`TOKEN_ENCRYPTION_ACTIVE_KEY_ID` configured; SenderWho encrypts the Yahoo app
password with that key ring.

Install the locked dependencies, build, apply migrations, and restart:

```bash
cd server
npm ci
npm run build
npx prisma migrate deploy
```

For Docker/Hostinger deployments, rebuild the API image so the `imapflow` and
`mailparser` production dependencies are included.

## 3. Connect in SenderWho

1. Install the newly built mobile application.
2. Open **Connect your inbox**.
3. Tap **Continue with Yahoo**.
4. Enter the full Yahoo address.
5. Enter the generated Yahoo app password.
6. Tap **Connect**.

The backend validates the credential directly against Yahoo IMAP over TLS before
storing anything. On success it stores only the encrypted app password, queues
the initial scan, and creates the SenderWho app session.

## 4. Acceptance test

Verify all of the following:

1. The dashboard changes from queued/syncing to partial or ready.
2. Recent Yahoo inbox messages and senders appear.
3. Older messages continue importing while status is partial.
4. Opening a Yahoo message loads its body and attachment names.
5. Mark read/unread changes Yahoo Mail.
6. Archive/unarchive and Trash/restore change Yahoo Mail.
7. A supported RFC 8058 one-click unsubscribe completes and stays removed after
   refresh.
8. Disconnect removes the encrypted credential from SenderWho.
9. Delete the SenderWho app password in Yahoo Account Security after
   disconnecting if access should be revoked at Yahoo as well.

## Operational notes

- Yahoo's official settings are `imap.mail.yahoo.com`, port `993`, SSL enabled.
- Initial imports are newest-first and use durable UID cursors.
- SenderWho fetches metadata during scans. Full MIME content is loaded on
  demand, capped at 10 MB, and is not stored as a full message body.
- App-password authentication does not use or expose the normal Yahoo password.
