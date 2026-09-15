import {
  resolveDatabaseTcpEndpoint,
  shouldApplyMigrationsAtRuntime,
} from "./database-endpoint";

describe("resolveDatabaseTcpEndpoint", () => {
  it("uses the host and non-default port from DATABASE_URL", () => {
    expect(
      resolveDatabaseTcpEndpoint({
        DATABASE_URL:
          "mysql://senderwho:secret@localhost:3307/senderwho?connection_limit=5",
      }),
    ).toEqual({ host: "127.0.0.1", port: 3307 });
  });

  it("lets explicit shared-hosting variables override DATABASE_URL", () => {
    expect(
      resolveDatabaseTcpEndpoint({
        DATABASE_URL: "mysql://user:secret@database.internal:3307/app",
        DB_HOST: "mysql.hostinger.internal",
        DB_PORT: "3308",
      }),
    ).toEqual({ host: "mysql.hostinger.internal", port: 3308 });
  });

  it("falls back safely when configuration is malformed", () => {
    expect(
      resolveDatabaseTcpEndpoint({
        DATABASE_URL: "not-a-url",
        DB_PORT: "70000",
      }),
    ).toEqual({ host: "127.0.0.1", port: 3306 });
  });
});

describe("shouldApplyMigrationsAtRuntime", () => {
  it("runs packaged migrations only on production shared hosting", () => {
    expect(
      shouldApplyMigrationsAtRuntime({
        NODE_ENV: "production",
        HOSTINGER_SHARED_HOSTING: "true",
      }),
    ).toBe(true);
    expect(shouldApplyMigrationsAtRuntime({ NODE_ENV: "production" })).toBe(
      false,
    );
    expect(
      shouldApplyMigrationsAtRuntime({
        NODE_ENV: "development",
        HOSTINGER_SHARED_HOSTING: "true",
      }),
    ).toBe(false);
  });
});
