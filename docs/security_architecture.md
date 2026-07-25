# SenderWho Security Architecture

Updated: 2026-07-21

This is the current, maintainable security plan for deploying SenderWho on one
Hostinger VPS without paid enterprise security products. Older audit documents
are historical assessments; this document is the deployment source of truth.

No application can be described as completely secure. SenderWho protects Gmail
metadata and credentials with the controls below, while the server owner must
keep the VPS, DNS, backups, and dependencies maintained.

SenderWho is not end-to-end encrypted. The backend must decrypt Google provider
tokens and process Gmail metadata to provide its features. Message bodies are not
required for the current metadata-based classification and must not be collected.

## Security implemented in the application

### Authentication and sessions

- Google authorization uses signed state, PKCE S256, an OIDC nonce, a short-lived
  one-time login record, an unguessable polling secret, exact callback checks,
  and required-scope validation.
- Google identity validation checks issuer, audience, subject, verified email,
  nonce, issue time, expiry, and agreement with the Gmail profile.
- Production access JWTs expire within 15 minutes and are tied to an application
  session. Every protected request verifies that the session and user remain
  active, so session revocation takes effect immediately.
- Refresh tokens are random, hashed at rest, rotated on use, linked into a token
  family, and protected by reuse detection and family-wide revocation.
- Sensitive operations require a recent Google reauthentication. Retried
  mutations retain the same idempotency key.

### API and data protection

- All non-public endpoints are denied by default unless they pass the global JWT
  and active-session guard.
- Database queries for user resources include the authenticated `userId`. Bulk
  operations verify ownership before performing a Gmail action.
- Request DTOs use a strict allowlist and reject unknown properties. Request
  bodies have size limits, and list and bulk operations have bounded inputs.
- Redis-backed throttling combines IP, user, and session identifiers. Public
  authentication, search, export, and destructive endpoints use tighter limits.
- Core mutations use a per-user, per-operation idempotency ledger to prevent
  accidental duplicate work.
- Production mock data and Swagger are disabled. CORS uses an exact HTTPS origin
  allowlist, Flutter release builds reject HTTP, and the API requires HTTPS when
  reached through the production reverse proxy.

### Gmail and email safety

- Google access and refresh tokens are encrypted with AES-256-GCM using a random
  nonce, authenticated record context, a key identifier, and a rotatable local
  key ring. The keys must never be committed to Git or stored in a public image.
- One-click unsubscribe permits only public HTTPS port 443 destinations and
  validates DNS, selected IP addresses, TLS hostnames, and redirects to reduce
  SSRF risk.
- Sender impersonation checks use real Gmail headers and authentication results.
  They detect evidence such as display-name/domain mismatch, lookalike domains,
  SPF/DKIM/DMARC failures, suspicious Reply-To values, and Gmail spam labels.
- Message risk remains separate from aggregated sender confidence. Alerts are
  explainable and deduplicated, and a display name alone never marks mail as
  malicious.

### Privacy, logging, and account control

- Structured logs include a correlation ID but exclude request bodies, query
  values, headers, tokens, message content, and raw exception details.
- Security-sensitive and destructive operations create user-scoped audit rows.
- Expired login, session, and idempotency records are removed according to the
  configured retention periods.
- Users can export their data, revoke sessions, disconnect Gmail, dismiss alerts,
  and delete their account.
- Secrets and Gmail credentials are never stored in Flutter application data.
  The mobile app stores only its rotating refresh credential in Keychain or the
  Android Keystore.

## Hostinger VPS deployment controls

These controls do not require paid security add-ons:

1. Run a supported LTS operating system and install security updates promptly.
2. Use Nginx or Caddy as the only public entry point. Obtain and automatically
   renew a free Let's Encrypt certificate. Redirect HTTP to HTTPS.
3. Allow only ports 22, 80, and 443 through the VPS firewall. Restrict SSH to a
   known administrator IP when practical, use SSH keys, disable password and
   root login, and install Fail2ban.
4. Do not publish MySQL or Redis ports to the internet. Keep them on a private
   Docker network or bind them only to `127.0.0.1`. Require strong, unique
   database and Redis passwords.
5. Run the API and worker as a non-root user. Do not run Adminer, Prisma Studio,
   Swagger, development mode, or mock data on the public server.
6. Keep production secrets in a root-owned environment file outside Git with
   permissions `600`. Use independent random values for JWT signing, the token
   encryption key ring, MySQL, Redis, and Google OAuth credentials.
7. Back up the database daily, encrypt the backup before it leaves the VPS, keep
   at least one copy outside the VPS, apply retention, and perform a restore test
   regularly. A backup stored only on the same server is not sufficient.
8. Use Docker log rotation or `logrotate`, review authentication/security errors,
   and configure basic disk, CPU, memory, certificate-expiry, and service-health
   monitoring using Hostinger's available monitoring or a free uptime monitor.
9. Deploy only committed Prisma migrations with `prisma migrate deploy`. Do not
   give the normal API database user schema-changing privileges after migration.
10. Run the repository build, tests, dependency audit, secret scan, and container
    scan before releases. Apply supported Node, Flutter, OS, and dependency
    security updates.

The current production startup validation requires certificate-validated MySQL
TLS and authenticated Redis TLS. These can use locally managed certificates and
do not require a paid service. Do not weaken that validation merely to make a
remote database connection start.

## Controls deliberately not claimed

The Hostinger plan does not claim that the following enterprise services exist:

- managed cloud KMS or workload identity;
- a paid WAF, API gateway, or dedicated DDoS product;
- a managed private cloud database or Redis service;
- an enterprise SIEM, immutable log archive, or staffed 24-hour SOC;
- point-in-time database recovery supplied by a managed database vendor;
- passkeys, device attestation, AI-based automatic blocking, or certificate
  pinning;
- completion of an independent penetration test or Google's restricted-scope
  security assessment.

These are optional future improvements, not advertised current features. The
existing deterministic checks and local encryption must remain because they are
useful and maintainable on the VPS.

## Required external release work

Hosting choice does not remove Google's requirements. Before allowing public
users, complete the OAuth consent-screen verification, publish the privacy policy
and account-deletion instructions, request only necessary Gmail scopes, and
complete any restricted-scope verification or security assessment required by
Google.

Before launch, verify the real Hostinger deployment rather than only the source:

- HTTPS and certificate renewal work;
- MySQL and Redis cannot be reached from the public internet;
- production secrets are not in Git, images, logs, or shell history;
- session revocation, throttling, ownership checks, and reauthentication work;
- backups can actually be restored;
- dependency and container scans have no unresolved critical findings;
- Google OAuth callbacks and mobile deep links use the production domains.
