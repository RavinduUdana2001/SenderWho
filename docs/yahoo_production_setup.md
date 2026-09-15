# Yahoo Mail OAuth production setup

SenderWho connects Yahoo Mail with Yahoo OAuth 2.0 and IMAP over TLS. The app
owner configures one Yahoo OAuth application. End users tap **Continue with
Yahoo**, authenticate on Yahoo's website, approve mailbox access, and return to
SenderWho. Users never create or enter app passwords.

## 1. Create the SenderWho Yahoo application

1. Sign in at <https://developer.yahoo.com/apps/>.
2. Create an application named `SenderWho`.
3. Use the production SenderWho website/domain when Yahoo requests the
   application URL or callback domain.
4. Configure this exact redirect URI:

   ```text
   https://senderwho.com/api/v1/auth/oauth/yahoo/callback
   ```

5. Request these delegated permissions:

   ```text
   openid
   email
   profile
   mail-r
   mail-w
   ```

6. Save the generated **Client ID (Consumer Key)** and **Client Secret
   (Consumer Secret)** securely.

Mail permissions are restricted. Creating a Yahoo developer application alone
does not guarantee production mailbox access. Submit the application through
Yahoo Sender Hub's developer-access process and request OAuth2 IMAP read/write
mail access. Do not release Yahoo login to clients until `mail-r` and `mail-w`
are approved for the application.

## 2. Configure Hostinger

Add these server environment values:

```env
YAHOO_OAUTH_ENABLED=false
YAHOO_CLIENT_ID=<Yahoo Consumer Key>
YAHOO_CLIENT_SECRET=<Yahoo Consumer Secret>
YAHOO_OAUTH_CALLBACK_URL=https://senderwho.com/api/v1/auth/oauth/yahoo/callback
YAHOO_IMAP_HOST=imap.mail.yahoo.com
YAHOO_IMAP_PORT=993
```

Keep `YAHOO_OAUTH_ENABLED=false` while Yahoo's approval is pending. The
production API and Gmail flow continue normally, and the app hides the Yahoo
button. Only change it to `true` after Yahoo confirms that both `mail-r` and
`mail-w` are active for this application.

Do not place these credentials in Flutter, GitHub, an APK, screenshots, or
messages. Keep the existing `TOKEN_ENCRYPTION_KEYS` and
`TOKEN_ENCRYPTION_ACTIVE_KEY_ID`; SenderWho encrypts every user's Yahoo OAuth
access and refresh tokens using that key ring.

Rebuild and restart the backend after saving the variables:

```bash
cd server
npm ci
npm run build
npx prisma migrate deploy
```

For Hostinger, deploy the current backend package and restart the Node
application after its successful build.

## 3. End-user connection

1. Open SenderWho.
2. Tap **Continue with Yahoo**.
3. Complete Yahoo sign-in in the secure browser.
4. Review and approve SenderWho's requested Mail read/write access.
5. Yahoo returns to the SenderWho callback page, which opens the mobile app.
6. SenderWho exchanges the completed login session and starts the initial scan.

The user never sees the Client ID, Client Secret, OAuth tokens, or an app
password.

## 4. Acceptance test

Verify all of the following with an approved Yahoo test account:

1. Yahoo's consent page displays SenderWho and the expected mail permissions.
2. The browser returns to SenderWho after approval.
3. The dashboard changes from queued/syncing to partial or ready.
4. Recent messages and senders appear; older mail continues importing.
5. Opening a message loads its body and attachment names.
6. Mark read/unread changes Yahoo Mail.
7. Archive/unarchive and Trash/restore change Yahoo Mail.
8. Supported one-click unsubscribe actions complete and remain removed.
9. Access tokens refresh automatically without asking the user to sign in.
10. Disconnect clears local credentials and users can revoke SenderWho from
    Yahoo Account Security.
11. Mail from a sender blocked in SenderWho is moved to Yahoo Trash on the next
    sync, matching the Gmail behavior.
12. A Yahoo-created SenderWho account can complete recent authentication for
    protected Settings actions without being redirected to Google.

For every write action in steps 6-8 and 11, open the same mailbox in Yahoo Mail
and confirm the result there. A successful SenderWho API response by itself is
not sufficient evidence that the provider-side change worked.

## 5. Yahoo approval and production gate

Do not enable the Yahoo button for production users until all of these are true:

- Yahoo has approved the SenderWho application for both `mail-r` and `mail-w`.
- The Yahoo Developer Network application owner, app name, application URL,
  privacy-policy URL, and callback URL exactly match the production service.
- `https://senderwho.com` and `https://senderwho.com/privacy` are public,
  readable without signing in, and use the same domain submitted to Yahoo.
- The callback is exactly
  `https://senderwho.com/api/v1/auth/oauth/yahoo/callback` with no alternate
  spelling, path, or trailing slash.
- The approved Client ID and Client Secret are installed only on the backend.
- A clean Yahoo test account completes the entire acceptance test above.
- Logs contain no access tokens, refresh tokens, authorization codes, message
  bodies, or Yahoo passwords.
- Disconnect, token expiry/revocation, retry, cancellation, and account
  deletion have been tested in production-like infrastructure.

Keep the Yahoo submission confirmation and approval email with the release
records. If Yahoo requests clarification, provide a short screen recording that
shows consent, mailbox scanning, read/unread, archive/restore, Trash/restore,
cleanup, and the matching changes in the Yahoo source mailbox.

## Operational notes

- Yahoo OAuth endpoints are server-side; the Client Secret must never be
  embedded in the mobile app.
- OAuth mail access uses Yahoo's OAuth bearer authentication with
  `imap.mail.yahoo.com`, port `993`, and certificate-validated TLS.
- `mail-r` provides mail read access and `mail-w` provides write access.
- Yahoo Mail developer access is subject to Yahoo approval and policies.
