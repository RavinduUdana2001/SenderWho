export type DatabaseTcpEndpoint = {
  host: string;
  port: number;
};

export function shouldApplyMigrationsAtRuntime(
  environment: NodeJS.ProcessEnv = process.env,
): boolean {
  return (
    environment.NODE_ENV === "production" &&
    environment.HOSTINGER_SHARED_HOSTING === "true"
  );
}

/**
 * Resolves the TCP endpoint used by the startup reachability check.
 * Explicit shared-hosting variables take precedence, while normal Prisma
 * deployments inherit their endpoint from DATABASE_URL.
 */
export function resolveDatabaseTcpEndpoint(
  environment: NodeJS.ProcessEnv = process.env,
): DatabaseTcpEndpoint {
  let urlHost: string | undefined;
  let urlPort: string | undefined;
  const databaseUrl = environment.DATABASE_URL?.trim();
  if (databaseUrl) {
    try {
      const parsed = new URL(databaseUrl);
      urlHost = parsed.hostname;
      urlPort = parsed.port;
    } catch {
      // Environment validation reports malformed URLs with the full context.
      // Keep this helper free of credentials and fall back to safe defaults.
    }
  }

  const configuredHost = environment.DB_HOST?.trim() || urlHost || "localhost";
  const host = configuredHost === "localhost" ? "127.0.0.1" : configuredHost;
  const rawPort = environment.DB_PORT?.trim() || urlPort || "3306";
  const parsedPort = Number(rawPort);
  const port =
    Number.isInteger(parsedPort) && parsedPort > 0 && parsedPort <= 65_535
      ? parsedPort
      : 3306;
  return { host, port };
}
