# Microsoft Outlook production setup

SenderWho uses Microsoft identity platform OAuth 2.0 and Microsoft Graph. One
backend-owned Entra app registration supports Outlook.com/Hotmail personal
accounts and Microsoft 365 work or school accounts. End users never give
SenderWho their Microsoft password.

## 1. Configure the Entra app registration

In the Microsoft Entra admin center, open **App registrations > SenderWho** and
configure:

- Supported account types: **Accounts in any organizational directory and
  personal Microsoft accounts**.
- Platform: **Web**.
- Redirect URI (exactly, with no trailing slash):

  ```text
  https://senderwho.com/api/v1/auth/oauth/microsoft/callback
  ```

- Implicit grant: leave both **Access tokens** and **ID tokens** disabled.
- Microsoft Graph delegated permissions:

  ```text
  User.Read
  Mail.ReadWrite
  ```

`Mail.Send` is not requested or used. `openid`, `profile`, `email`, and
`offline_access` are requested dynamically by the standards-based OAuth flow;
they are not application permissions.

Create a client secret under **Certificates & secrets** and copy its **Value**
immediately. Never copy its Secret ID in place of the secret Value. Store the
Value only in the backend environment.

## 2. Configure Hostinger

Add these variables to the Node.js application environment:

```env
MICROSOFT_OAUTH_ENABLED=false
MICROSOFT_CLIENT_ID=<Application (client) ID>
MICROSOFT_CLIENT_SECRET=<client secret Value, not Secret ID>
MICROSOFT_OAUTH_CALLBACK_URL=https://senderwho.com/api/v1/auth/oauth/microsoft/callback
```

Deploy the new backend while the feature remains disabled, run the Prisma
migrations, and restart the application:

```bash
npm ci
npm run build
npx prisma migrate deploy
```

Confirm the API is healthy, then change `MICROSOFT_OAUTH_ENABLED=true` and
restart once more. The Flutter app reads `GET /api/v1/auth/providers` and only
shows Microsoft sign-in after the backend reports that all three OAuth values
are present and the feature flag is enabled.

Do not place the Client Secret in Flutter, an APK/IPA, GitHub, screenshots,
chat, or email. Keep the existing `TOKEN_ENCRYPTION_KEYS` and
`TOKEN_ENCRYPTION_ACTIVE_KEY_ID`; they encrypt each user's Microsoft access and
refresh tokens at rest.

## 3. Implemented end-user flow

1. Flutter starts a short-lived SenderWho OAuth session.
2. The system browser opens Microsoft's `/authorize` endpoint with state,
   nonce, Authorization Code flow, and PKCE.
3. Microsoft redirects to the backend Web callback.
4. The backend validates the state, nonce, ID-token signature, issuer,
   audience, expiry, Microsoft Graph identity, and granted scopes.
5. The backend stores encrypted access/refresh tokens and queues the first
   mailbox scan.
6. The callback page deep-links to `senderwho://oauth/callback`; Flutter
   exchanges the one-time login session and opens the app.
7. Later scans refresh the access token without asking the user to sign in.

Mailbox synchronization uses folder-specific Microsoft Graph delta links and
immutable message IDs. It handles provider throttling with bounded retries and
supports read/unread, archive/unarchive, Trash/restore, cleanup, sender
analysis, unsubscribe-header detection, and on-demand message content.

## 4. Production acceptance test

Test at least one personal Outlook.com account and one Microsoft 365 work or
school account:

1. Microsoft consent shows SenderWho and only the expected delegated access.
2. Approval returns to SenderWho automatically.
3. Account status changes from queued/scanning to ready (or ready while older
   mail continues syncing).
4. Inbox, archive, junk, and deleted-item metadata appear correctly; sent,
   draft, and outbox messages are excluded.
5. Opening a message loads its body and attachment names on demand.
6. Read/unread, archive/unarchive, Trash/restore, cleanup, and supported
   unsubscribe actions are reflected in Outlook itself.
7. A second scan processes only delta changes and does not duplicate messages.
8. Token refresh works after the short-lived access token expires.
9. Revoked consent produces a friendly reconnect state.
10. Disconnect clears locally stored provider credentials and stops jobs.

If a work tenant blocks user consent, its administrator may need to approve the
delegated permissions for that tenant. This is a tenant policy issue; it does
not require application permissions or a client secret in the mobile app.
