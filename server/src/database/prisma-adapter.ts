import { PrismaMariaDb } from "@prisma/adapter-mariadb";

const DEFAULT_CONNECTION_LIMIT = 5;

export interface MariaDbConnectionConfig {
  host: string;
  port: number;
  user: string;
  password: string;
  database: string;
  connectionLimit: number;
  allowPublicKeyRetrieval?: true;
  ssl?: {
    rejectUnauthorized: true;
  };
}

export function createPrismaAdapter(): PrismaMariaDb {
  return new PrismaMariaDb(readMariaDbConnectionConfig(), {
    onConnectionError: (error) => {
      console.error(
        JSON.stringify({
          event: "database.pool_connection.failed",
          code: error.code,
          errno: error.errno,
          sqlState: error.sqlState,
        }),
      );
    },
  });
}

export function readMariaDbConnectionConfig(
  databaseUrl = process.env.DATABASE_URL,
): MariaDbConnectionConfig {
  if (!databaseUrl) {
    if (process.env.MOCK_DATA_ENABLED === "true") {
      return {
        host: "127.0.0.1",
        port: 3306,
        user: "mock",
        password: "mock",
        database: "mock",
        connectionLimit: 1,
      };
    }
    throw new Error("DATABASE_URL is required.");
  }

  const url = new URL(databaseUrl);
  if (url.protocol !== "mysql:") {
    throw new Error("DATABASE_URL must be a MySQL connection URL.");
  }

  const port = parsePositiveInteger(url.port || "3306", "database port");
  const connectionLimit = parsePositiveInteger(
    process.env.DB_CONNECTION_LIMIT ??
      url.searchParams.get("connection_limit") ??
      String(DEFAULT_CONNECTION_LIMIT),
    "DB_CONNECTION_LIMIT",
  );
  const database = decodeURIComponent(url.pathname.replace(/^\/+/, ""));
  if (!url.hostname || !url.username || !database) {
    throw new Error(
      "DATABASE_URL must include a database host, user, and database name.",
    );
  }

  return {
    host: url.hostname,
    port,
    user: decodeURIComponent(url.username),
    password: decodeURIComponent(url.password),
    database,
    connectionLimit,
    ...(["localhost", "127.0.0.1"].includes(url.hostname)
      ? { allowPublicKeyRetrieval: true as const }
      : {}),
    ...(url.searchParams.get("sslaccept") === "strict"
      ? { ssl: { rejectUnauthorized: true as const } }
      : {}),
  };
}

function parsePositiveInteger(value: string, label: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1) {
    throw new Error(`${label} must be a positive integer.`);
  }
  return parsed;
}
