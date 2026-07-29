export default () => ({
  nodeEnv: process.env.NODE_ENV ?? "development",
  mockDataEnabled: process.env.MOCK_DATA_ENABLED === "true",
  port: Number(process.env.PORT ?? 3000),
  apiPrefix: process.env.API_PREFIX ?? "api/v1",
  corsOrigins: (process.env.CORS_ORIGINS ?? "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean),
  http: {
    trustedProxyHops: Number(process.env.TRUST_PROXY_HOPS ?? 0),
    requestBodyLimit: process.env.REQUEST_BODY_LIMIT ?? "256kb",
    swaggerEnabled:
      process.env.SWAGGER_ENABLED === "true" ||
      (process.env.NODE_ENV ?? "development") !== "production",
  },
  publicSite: {
    legalName: process.env.PUBLIC_LEGAL_NAME?.trim() || "SenderWho",
    supportEmail: process.env.PUBLIC_SUPPORT_EMAIL?.trim() || "",
    effectiveDate:
      process.env.PUBLIC_LEGAL_EFFECTIVE_DATE?.trim() || "2026-07-29",
  },
  databaseUrl: process.env.DATABASE_URL,
  auth: {
    jwtSecret: process.env.JWT_SECRET,
    jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? "15m",
    refreshTokenDays: Number(process.env.REFRESH_TOKEN_EXPIRES_DAYS ?? 365),
    tokenEncryptionKey: process.env.TOKEN_ENCRYPTION_KEY,
    tokenEncryptionKeys: process.env.TOKEN_ENCRYPTION_KEYS,
    tokenEncryptionActiveKeyId: process.env.TOKEN_ENCRYPTION_ACTIVE_KEY_ID,
  },
  oauth: {
    google: {
      clientId: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
      callbackUrl: process.env.GOOGLE_OAUTH_CALLBACK_URL,
    },
    microsoft: {
      clientId: process.env.MICROSOFT_CLIENT_ID,
      clientSecret: process.env.MICROSOFT_CLIENT_SECRET,
      callbackUrl: process.env.MICROSOFT_OAUTH_CALLBACK_URL,
    },
    yahoo: {
      enabled: process.env.YAHOO_OAUTH_ENABLED === "true",
      clientId: process.env.YAHOO_CLIENT_ID ?? process.env.YAHOO_CONSUMER_KEY,
      clientSecret:
        process.env.YAHOO_CLIENT_SECRET ?? process.env.YAHOO_CONSUMER_SECRET,
      callbackUrl: process.env.YAHOO_OAUTH_CALLBACK_URL,
      imapHost: process.env.YAHOO_IMAP_HOST ?? "imap.mail.yahoo.com",
      imapPort: Number(process.env.YAHOO_IMAP_PORT ?? 993),
      smtpHost: process.env.YAHOO_SMTP_HOST ?? "smtp.mail.yahoo.com",
      smtpPort: Number(process.env.YAHOO_SMTP_PORT ?? 465),
    },
  },
  gmailSync: {
    // Smaller batches and bounded concurrency avoid Gmail per-user quota
    // bursts. Continuation jobs still import up to maxMessages per pass.
    maxMessages: Number(process.env.GMAIL_INITIAL_SYNC_MAX_MESSAGES ?? 500),
    batchSize: Number(process.env.GMAIL_SYNC_BATCH_SIZE ?? 20),
    concurrency: Number(process.env.GMAIL_SYNC_CONCURRENCY ?? 5),
  },
  retention: {
    messageDays: Number(process.env.MESSAGE_RETENTION_DAYS ?? 365),
    auditDays: Number(process.env.AUDIT_RETENTION_DAYS ?? 730),
    jobDays: Number(process.env.JOB_RETENTION_DAYS ?? 90),
  },
});
