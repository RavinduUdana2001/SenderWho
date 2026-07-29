import { readMariaDbConnectionConfig } from "./prisma-adapter";

describe("Prisma MariaDB adapter configuration", () => {
  const originalConnectionLimit = process.env.DB_CONNECTION_LIMIT;

  afterEach(() => {
    if (originalConnectionLimit === undefined) {
      delete process.env.DB_CONNECTION_LIMIT;
    } else {
      process.env.DB_CONNECTION_LIMIT = originalConnectionLimit;
    }
  });

  it("decodes Hostinger credentials without exposing them in logs", () => {
    expect(
      readMariaDbConnectionConfig(
        "mysql://mail%40user:p%40ss%2Fword@127.0.0.1:3306/senderwho",
      ),
    ).toEqual({
      host: "127.0.0.1",
      port: 3306,
      user: "mail@user",
      password: "p@ss/word",
      database: "senderwho",
      connectionLimit: 5,
      allowPublicKeyRetrieval: true,
    });
  });

  it("supports a bounded connection limit and certificate-validated TLS", () => {
    process.env.DB_CONNECTION_LIMIT = "3";

    expect(
      readMariaDbConnectionConfig(
        "mysql://user:secret@db.example.test:3307/app?sslaccept=strict",
      ),
    ).toMatchObject({
      host: "db.example.test",
      port: 3307,
      connectionLimit: 3,
      ssl: { rejectUnauthorized: true },
    });
  });

  it("rejects invalid connection limits before opening a pool", () => {
    process.env.DB_CONNECTION_LIMIT = "0";

    expect(() =>
      readMariaDbConnectionConfig(
        "mysql://user:secret@127.0.0.1:3306/senderwho",
      ),
    ).toThrow("DB_CONNECTION_LIMIT must be a positive integer.");
  });
});
