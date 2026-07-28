type Environment = Record<string, string | undefined>;

export function validateEnvironment(environment: Environment): Environment {
  if (
    environment.NODE_ENV === "production" &&
    environment.MOCK_DATA_ENABLED === "true"
  ) {
    throw new Error("MOCK_DATA_ENABLED must never be true in production.");
  }
  if (environment.MOCK_DATA_ENABLED === "true") return environment;

  requireValue(environment, "DATABASE_URL");
  requireValue(environment, "GOOGLE_CLIENT_ID");
  requireValue(environment, "GOOGLE_CLIENT_SECRET");
  const callbackUrl = requireValue(environment, "GOOGLE_OAUTH_CALLBACK_URL");
  const yahooClientId =
    environment.YAHOO_CLIENT_ID?.trim() ??
    environment.YAHOO_CONSUMER_KEY?.trim();
  const yahooClientSecret =
    environment.YAHOO_CLIENT_SECRET?.trim() ??
    environment.YAHOO_CONSUMER_SECRET?.trim();
  const yahooCallbackUrl = environment.YAHOO_OAUTH_CALLBACK_URL?.trim();
  const yahooConfigured = Boolean(yahooClientId || yahooClientSecret);
  const yahooEnabled = environment.YAHOO_OAUTH_ENABLED === "true";
  if (yahooConfigured || yahooEnabled) {
    if (!yahooClientId || !yahooClientSecret || !yahooCallbackUrl) {
      throw new Error(
        "YAHOO_CLIENT_ID, YAHOO_CLIENT_SECRET, and YAHOO_OAUTH_CALLBACK_URL must be configured together.",
      );
    }
    try {
      new URL(yahooCallbackUrl);
    } catch {
      throw new Error("YAHOO_OAUTH_CALLBACK_URL must be a valid URL.");
    }
  }
  const jwtSecret = requireValue(environment, "JWT_SECRET");
  const legacyEncryptionKey = environment.TOKEN_ENCRYPTION_KEY?.trim();

  if (!environment.DATABASE_URL?.startsWith("mysql://")) {
    throw new Error("DATABASE_URL must be a MySQL connection URL.");
  }
  if (jwtSecret.length < 32) {
    throw new Error("JWT_SECRET must contain at least 32 characters.");
  }

  if (
    legacyEncryptionKey &&
    Buffer.from(legacyEncryptionKey, "base64").length !== 32
  ) {
    throw new Error(
      "TOKEN_ENCRYPTION_KEY must decode to exactly 32 bytes. Use: openssl rand -base64 32",
    );
  }

  try {
    new URL(callbackUrl);
  } catch {
    throw new Error("GOOGLE_OAUTH_CALLBACK_URL must be a valid URL.");
  }

  if (environment.NODE_ENV === "production") {
    for (const [key, value] of [
      ["DATABASE_URL", environment.DATABASE_URL],
      ["GOOGLE_CLIENT_ID", environment.GOOGLE_CLIENT_ID],
      ["GOOGLE_CLIENT_SECRET", environment.GOOGLE_CLIENT_SECRET],
      ["JWT_SECRET", environment.JWT_SECRET],
      ["TOKEN_ENCRYPTION_KEYS", environment.TOKEN_ENCRYPTION_KEYS],
    ] as const) {
      if (value && /REPLACE_WITH|CHANGE_ME|YOUR_/i.test(value)) {
        throw new Error(`${key} still contains a production placeholder.`);
      }
    }
    validateIntegerRange(
      environment,
      "GMAIL_INITIAL_SYNC_MAX_MESSAGES",
      25,
      500,
      500,
    );
    validateIntegerRange(environment, "GMAIL_SYNC_BATCH_SIZE", 5, 25, 20);
    validateIntegerRange(environment, "GMAIL_SYNC_CONCURRENCY", 1, 8, 5);
    const databaseUrl = new URL(environment.DATABASE_URL!);
    const privateDockerDataServices =
      environment.ALLOW_PRIVATE_DOCKER_DATA_SERVICES === "true";
    const hostingerSharedHosting =
      environment.HOSTINGER_SHARED_HOSTING === "true";
    if (
      !privateDockerDataServices &&
      !hostingerSharedHosting &&
      databaseUrl.searchParams.get("sslaccept") !== "strict"
    ) {
      throw new Error(
        "Production DATABASE_URL must require certificate-validated TLS with sslaccept=strict.",
      );
    }
    if (privateDockerDataServices && databaseUrl.hostname !== "mysql") {
      throw new Error(
        "Private Docker database mode must use the exact internal host mysql.",
      );
    }
    if (
      hostingerSharedHosting &&
      !["localhost", "127.0.0.1"].includes(databaseUrl.hostname)
    ) {
      throw new Error(
        "Hostinger shared-hosting database mode must use localhost or 127.0.0.1.",
      );
    }
    if (!callbackUrl.startsWith("https://")) {
      throw new Error(
        "GOOGLE_OAUTH_CALLBACK_URL must use HTTPS in production.",
      );
    }
    if (
      (yahooConfigured || yahooEnabled) &&
      yahooCallbackUrl &&
      !yahooCallbackUrl.startsWith("https://")
    ) {
      throw new Error("YAHOO_OAUTH_CALLBACK_URL must use HTTPS in production.");
    }
    if (!environment.CORS_ORIGINS?.trim()) {
      throw new Error("CORS_ORIGINS must be explicit in production.");
    }
    const origins = environment.CORS_ORIGINS.split(",").map((value) =>
      value.trim(),
    );
    if (
      origins.some(
        (origin) =>
          !origin.startsWith("https://") ||
          origin.includes("*") ||
          origin.endsWith("/"),
      )
    ) {
      throw new Error(
        "Production CORS_ORIGINS must be exact HTTPS origins without wildcards or trailing slashes.",
      );
    }
    const trustedProxyHops = Number(environment.TRUST_PROXY_HOPS);
    if (!Number.isInteger(trustedProxyHops) || trustedProxyHops < 0) {
      throw new Error(
        "TRUST_PROXY_HOPS must be an explicit non-negative integer in production.",
      );
    }
    if (environment.SWAGGER_ENABLED === "true") {
      throw new Error("SWAGGER_ENABLED must not be true in production.");
    }
    if (
      !environment.TOKEN_ENCRYPTION_KEYS?.trim() ||
      !environment.TOKEN_ENCRYPTION_ACTIVE_KEY_ID?.trim()
    ) {
      throw new Error(
        "Production requires TOKEN_ENCRYPTION_KEYS and TOKEN_ENCRYPTION_ACTIVE_KEY_ID for versioned key rotation.",
      );
    }
    const keyRing = new Map<string, Buffer>();
    for (const entry of environment.TOKEN_ENCRYPTION_KEYS.split(",")) {
      const separator = entry.indexOf(":");
      const keyId = entry.slice(0, separator).trim();
      const encoded = entry.slice(separator + 1).trim();
      const decoded = Buffer.from(encoded, "base64");
      if (
        separator <= 0 ||
        !/^[A-Za-z0-9_-]{1,40}$/.test(keyId) ||
        decoded.length !== 32
      ) {
        throw new Error(
          "Every TOKEN_ENCRYPTION_KEYS entry must use key-id:base64-encoded-32-byte-key.",
        );
      }
      keyRing.set(keyId, decoded);
    }
    if (!keyRing.has(environment.TOKEN_ENCRYPTION_ACTIVE_KEY_ID.trim())) {
      throw new Error(
        "TOKEN_ENCRYPTION_ACTIVE_KEY_ID must identify a configured key-ring entry.",
      );
    }
    const accessTokenSeconds = durationSeconds(
      environment.JWT_EXPIRES_IN ?? "15m",
    );
    if (accessTokenSeconds <= 0 || accessTokenSeconds > 15 * 60) {
      throw new Error(
        "JWT_EXPIRES_IN must be a positive duration no longer than 15 minutes in production.",
      );
    }
    const refreshDays = Number(environment.REFRESH_TOKEN_EXPIRES_DAYS ?? 365);
    if (
      !Number.isInteger(refreshDays) ||
      refreshDays < 1 ||
      refreshDays > 365
    ) {
      throw new Error(
        "REFRESH_TOKEN_EXPIRES_DAYS must be between 1 and 365 in production.",
      );
    }
    const requestBodyBytes = byteSize(
      environment.REQUEST_BODY_LIMIT ?? "256kb",
    );
    if (requestBodyBytes <= 0 || requestBodyBytes > 1024 * 1024) {
      throw new Error(
        "REQUEST_BODY_LIMIT must be an explicit positive size no larger than 1mb.",
      );
    }
  }

  if (!legacyEncryptionKey && environment.NODE_ENV !== "production") {
    throw new Error(
      "TOKEN_ENCRYPTION_KEY is required outside production when mock data is disabled.",
    );
  }

  return environment;
}

function durationSeconds(value: string): number {
  const match = /^(\d+)(s|m|h)$/.exec(value.trim());
  if (!match) return Number.NaN;
  const amount = Number(match[1]);
  return amount * (match[2] === "h" ? 3600 : match[2] === "m" ? 60 : 1);
}

function byteSize(value: string): number {
  const match = /^(\d+)(b|kb|mb)$/i.exec(value.trim());
  if (!match) return Number.NaN;
  const amount = Number(match[1]);
  const unit = match[2].toLowerCase();
  return amount * (unit === "mb" ? 1024 * 1024 : unit === "kb" ? 1024 : 1);
}

function requireValue(environment: Environment, key: string): string {
  const value = environment[key]?.trim();
  if (!value) throw new Error(`${key} is required when mock data is disabled.`);
  return value;
}

function validateIntegerRange(
  environment: Environment,
  key: string,
  minimum: number,
  maximum: number,
  defaultValue: number,
) {
  const value = Number(environment[key] ?? defaultValue);
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new Error(`${key} must be an integer from ${minimum} to ${maximum}.`);
  }
}
