import { validateEnvironment } from "./validate-environment";

describe("validateEnvironment", () => {
  const key = Buffer.alloc(32, 7).toString("base64");
  const production = {
    NODE_ENV: "production",
    MOCK_DATA_ENABLED: "false",
    DATABASE_URL:
      "mysql://senderwho:password@database:3306/senderwho?sslaccept=strict",
    GOOGLE_CLIENT_ID: "google-client-id",
    GOOGLE_CLIENT_SECRET: "google-client-secret",
    GOOGLE_OAUTH_CALLBACK_URL:
      "https://api.senderwho.example/api/v1/auth/oauth/google/callback",
    YAHOO_CLIENT_ID: "yahoo-client-id",
    YAHOO_CLIENT_SECRET: "yahoo-client-secret",
    YAHOO_OAUTH_ENABLED: "true",
    YAHOO_OAUTH_CALLBACK_URL:
      "https://api.senderwho.example/api/v1/auth/oauth/yahoo/callback",
    JWT_SECRET: "a-production-jwt-secret-with-at-least-32-characters",
    JWT_EXPIRES_IN: "15m",
    REFRESH_TOKEN_EXPIRES_DAYS: "30",
    TOKEN_ENCRYPTION_KEYS: `key-2026-07:${key}`,
    TOKEN_ENCRYPTION_ACTIVE_KEY_ID: "key-2026-07",
    CORS_ORIGINS: "https://app.senderwho.example",
    TRUST_PROXY_HOPS: "1",
    REQUEST_BODY_LIMIT: "256kb",
    SWAGGER_ENABLED: "false",
  };

  it("accepts an explicit hardened production configuration", () => {
    expect(validateEnvironment({ ...production })).toEqual(production);
  });

  it("validates optional public-site contact details", () => {
    expect(() =>
      validateEnvironment({
        ...production,
        PUBLIC_SUPPORT_EMAIL: "support@senderwho.com",
        PUBLIC_LEGAL_EFFECTIVE_DATE: "2026-07-29",
      }),
    ).not.toThrow();
    expect(() =>
      validateEnvironment({
        ...production,
        PUBLIC_SUPPORT_EMAIL: "not-an-email",
      }),
    ).toThrow("PUBLIC_SUPPORT_EMAIL must be a valid email address");
    expect(() =>
      validateEnvironment({
        ...production,
        PUBLIC_LEGAL_EFFECTIVE_DATE: "29/07/2026",
      }),
    ).toThrow("must use the YYYY-MM-DD format");
  });

  it("requires Yahoo OAuth credentials in production", () => {
    expect(() =>
      validateEnvironment({
        ...production,
        YAHOO_CLIENT_ID: "",
        YAHOO_CLIENT_SECRET: "",
        YAHOO_OAUTH_CALLBACK_URL: "",
      }),
    ).toThrow("must be configured together");
  });

  it("allows Gmail production while Yahoo approval is pending", () => {
    expect(() =>
      validateEnvironment({
        ...production,
        YAHOO_OAUTH_ENABLED: "false",
        YAHOO_CLIENT_ID: "",
        YAHOO_CLIENT_SECRET: "",
        YAHOO_OAUTH_CALLBACK_URL: "",
      }),
    ).not.toThrow();
  });

  it("requires complete Yahoo settings when a credential is configured", () => {
    expect(() =>
      validateEnvironment({
        ...production,
        YAHOO_CLIENT_ID: "partial-yahoo-client",
        YAHOO_CLIENT_SECRET: "",
        YAHOO_OAUTH_CALLBACK_URL:
          "https://api.senderwho.example/api/v1/auth/oauth/yahoo/callback",
      }),
    ).toThrow("must be configured together");
  });

  it("refuses mock mode in production", () => {
    expect(() =>
      validateEnvironment({ ...production, MOCK_DATA_ENABLED: "true" }),
    ).toThrow("must never be true");
  });

  it("refuses production placeholders and unsafe Gmail scan limits", () => {
    expect(() =>
      validateEnvironment({
        ...production,
        GOOGLE_CLIENT_SECRET: "REPLACE_WITH_GOOGLE_CLIENT_SECRET",
      }),
    ).toThrow("GOOGLE_CLIENT_SECRET still contains a production placeholder");
    expect(() =>
      validateEnvironment({
        ...production,
        GMAIL_SYNC_BATCH_SIZE: "50",
      }),
    ).toThrow("GMAIL_SYNC_BATCH_SIZE must be an integer from 5 to 25");
    expect(() =>
      validateEnvironment({
        ...production,
        GMAIL_SYNC_CONCURRENCY: "20",
      }),
    ).toThrow("GMAIL_SYNC_CONCURRENCY must be an integer from 1 to 8");
    expect(() =>
      validateEnvironment({
        ...production,
        DB_CONNECTION_LIMIT: "20",
      }),
    ).toThrow("DB_CONNECTION_LIMIT must be an integer from 1 to 10");
  });

  it("requires certificate-validated MySQL transport by default", () => {
    expect(() =>
      validateEnvironment({
        ...production,
        DATABASE_URL: "mysql://senderwho:password@database:3306/senderwho",
      }),
    ).toThrow("sslaccept=strict");
  });

  it("allows a private database only on the exact Docker host", () => {
    expect(() =>
      validateEnvironment({
        ...production,
        ALLOW_PRIVATE_DOCKER_DATA_SERVICES: "true",
        DATABASE_URL: "mysql://senderwho:password@mysql:3306/senderwho",
      }),
    ).not.toThrow();
    expect(() =>
      validateEnvironment({
        ...production,
        HOSTINGER_SHARED_HOSTING: "true",
        DATABASE_URL: "mysql://senderwho:password@127.0.0.1:3306/senderwho",
      }),
    ).not.toThrow();
    expect(() =>
      validateEnvironment({
        ...production,
        ALLOW_PRIVATE_DOCKER_DATA_SERVICES: "true",
        DATABASE_URL: "mysql://senderwho:password@public-db:3306/senderwho",
      }),
    ).toThrow("exact internal host mysql");
  });

  it("allows Hostinger shared hosting only with local MySQL", () => {
    expect(() =>
      validateEnvironment({
        ...production,
        HOSTINGER_SHARED_HOSTING: "true",
        DATABASE_URL: "mysql://senderwho:password@localhost:3306/senderwho",
      }),
    ).not.toThrow();
    expect(() =>
      validateEnvironment({
        ...production,
        HOSTINGER_SHARED_HOSTING: "true",
        DATABASE_URL: "mysql://senderwho:password@remote-db:3306/senderwho",
      }),
    ).toThrow("use localhost or 127.0.0.1");
  });
});
