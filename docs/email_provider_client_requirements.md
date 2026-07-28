# SenderWho Email Provider Client Requirements

This checklist explains what the client must provide before SenderWho can connect Gmail and Yahoo accounts in production, and how user permission should work inside the app.

## Short Answer

The user does not give email access every time they open the app.

The correct flow is:

```text
1. User logs into SenderWho.
2. User taps Connect Gmail or Connect Yahoo.
3. Provider consent opens in browser/system web auth.
4. User grants the requested permissions once for that email account.
5. Backend receives an authorization code or mailbox credential.
6. Backend stores the long-lived credential encrypted.
7. Background jobs sync the mailbox later without asking again.
```

The user only needs to reconnect when they revoke access, the token expires permanently, the password/app password is deleted, or the app needs a new higher-risk permission scope.

## What We Need From The Client

### Business And App Details

- Final app name: `SenderWho`
- Company/legal owner name
- Support email address
- Public website/domain
- Privacy policy URL
- Terms of service URL
- Data deletion/account deletion URL or instructions
- App logo/icon
- Short app description for OAuth consent screens
- App Store / Play Store package names when ready

These are required because Google/Yahoo users must see who is asking for mailbox access and why.

### Backend Details

- Production API URL, for example `https://api.senderwho.com`
- OAuth callback URLs:

```text
https://api.senderwho.com/api/v1/auth/oauth/google/callback
https://api.senderwho.com/api/v1/auth/oauth/yahoo/callback
```

- Staging callback URLs if there is a staging backend
- Production `TOKEN_ENCRYPTION_KEY`
- Production `JWT_SECRET`
- MySQL production connection string
- Redis production connection string

## Gmail Setup

The client needs a Google Cloud project with:

- Gmail API enabled
- OAuth consent screen configured
- OAuth client ID and client secret for the backend
- Authorized redirect URI matching the backend callback URL
- Test users while the app is in testing mode
- Verification submission before public release

Environment values:

```text
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_OAUTH_CALLBACK_URL=https://api.senderwho.com/api/v1/auth/oauth/google/callback
```

### Recommended Gmail Permission Plan

Start with the smallest useful access.

For dashboard, sender list, inbox health, categories, and security alerts:

```text
https://www.googleapis.com/auth/gmail.metadata
```

This can read message metadata such as headers and labels, not full email bodies.

If the product needs message snippets/body preview:

```text
https://www.googleapis.com/auth/gmail.readonly
```

If the product needs cleanup actions such as moving messages to trash, marking read, labels, or unsubscribe workflows that modify messages:

```text
https://www.googleapis.com/auth/gmail.modify
```

Avoid this unless absolutely required:

```text
https://mail.google.com/
```

That broad Gmail scope can read, compose, send, and permanently delete all Gmail mail. For SenderWho, use narrower scopes wherever possible.

Important: `gmail.metadata`, `gmail.readonly`, and `gmail.modify` are restricted Gmail scopes. A public app will need Google verification, and if restricted Gmail data is stored or transmitted through the backend, Google can require a security assessment.

## Yahoo Setup

SenderWho uses Yahoo OAuth 2.0 with IMAP. The application must receive Yahoo
approval for the restricted read/write mail scopes before public release.

The client must provide one application-wide credential pair:

```text
YAHOO_OAUTH_ENABLED=false
YAHOO_CLIENT_ID=
YAHOO_CLIENT_SECRET=
YAHOO_OAUTH_CALLBACK_URL=https://api.senderwho.com/api/v1/auth/oauth/yahoo/callback
```

Request `openid`, `email`, `profile`, `mail-r`, and `mail-w`. See the
[Yahoo production setup](yahoo_production_setup.md). End users sign in on
Yahoo's consent page and never enter developer keys or app passwords.
Keep the feature flag `false` until Yahoo approves both mail scopes; Gmail
remains available and the mobile app hides Yahoo during that period.

Yahoo IMAP settings:

```text
YAHOO_IMAP_HOST=imap.mail.yahoo.com
YAHOO_IMAP_PORT=993
```

The backend encrypts OAuth access and refresh tokens at rest using the configured
versioned token-encryption key ring.

## How The App Flow Should Work

### SenderWho Login

This is only for the app account.

```text
User signs in to SenderWho
Backend creates app session/JWT
Flutter stores app session token in secure storage
```

This does not automatically give Gmail/Yahoo access.

### Connect Gmail

```text
Flutter calls POST /api/v1/auth/oauth/google/start
Backend returns Google authorization URL
Flutter opens system browser/web auth session
User grants access on Google consent screen
Google redirects to backend callback with code
Backend exchanges code for access token + refresh token
Backend encrypts refresh token and saves email account
Backend queues first inbox scan
Flutter shows syncing state
```

Use `access_type=offline` when building the Google authorization URL. That is what allows the backend to receive a refresh token and sync later without asking the user every time.

### Connect Yahoo

```text
Flutter calls POST /api/v1/auth/oauth/yahoo/start
Backend returns Yahoo authorization URL
User signs in through Yahoo consent page
Yahoo redirects to backend callback
Backend validates OAuth IMAP access and stores encrypted tokens
Backend queues first sync
Flutter exchanges the completed login session and opens the dashboard
```

## Should We Ask For All Permissions At One Time?

Do not ask for everything at the beginning.

Recommended production approach:

```text
First connect: metadata/read-only access for analysis
Cleanup action: request modify access only when the user wants cleanup
Permanent delete: avoid; use trash/move/delete-safe flow instead
Send email: request send permission only if the product truly sends mail
```

This improves user trust and makes OAuth verification easier to explain.

## What Happens After Tokens Are Saved

The mobile app should not call Gmail/Yahoo directly for scanning.

Backend jobs should handle:

- Refreshing access tokens
- Syncing inbox metadata
- Creating sender records
- Calculating risk/trust scores
- Creating cleanup suggestions
- Running unsubscribe/cleanup jobs after explicit user confirmation

The Flutter app reads SenderWho API data only:

```text
GET /api/v1/dashboard
GET /api/v1/senders
GET /api/v1/security-alerts
POST /api/v1/cleanup/jobs
```

## Data To Store

Store only what the product needs:

- Email account provider and address
- Encrypted OAuth refresh token
- Provider message IDs
- Sender name/email/domain
- Subject/snippet only if required
- Labels/categories
- Received date
- Risk flags
- Cleanup job status

Avoid storing full email body content unless a specific feature truly requires it.

## Production Warning

Gmail restricted scopes can trigger Google app verification and possible security assessment. Plan this before public launch, not after development is finished.

Yahoo Mail OAuth scopes are restricted. Public Yahoo scanning must not be
enabled until Yahoo approves the application's `mail-r` and `mail-w` access.

## References

- Gmail API scopes: https://developers.google.com/workspace/gmail/api/auth/scopes
- Google OAuth 2.0 web server flow: https://developers.google.com/identity/protocols/oauth2/web-server
- Yahoo OAuth 2.0 guide: https://developer.yahoo.com/oauth2/guide/
- Yahoo IMAP settings: https://help.yahoo.com/kb/SLN4075.html
- Yahoo Mail developer access: https://senders.yahooinc.com/developer/developer-access/
