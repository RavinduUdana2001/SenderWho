import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { PrismaClient } from "@prisma/client";

const MIGRATION_LOCK = "senderwho_schema_migrations";

export async function applyMysqlMigrations(): Promise<void> {
  if (!process.env.DATABASE_URL) throw new Error("DATABASE_URL is required.");

  const migrationsPath = path.join(__dirname, "..", "..", "prisma", "migrations");
  if (!existsSync(migrationsPath)) {
    throw new Error(`Packaged migrations are missing at ${migrationsPath}.`);
  }

  const prisma = new PrismaClient();
  console.log(JSON.stringify({ event: "database.connection.starting" }));
  let lockAcquired = false;
  try {
    const lockRows = await prisma.$queryRawUnsafe<Array<{ acquired: bigint | number }>>(
      "SELECT GET_LOCK(?, 30) AS acquired",
      MIGRATION_LOCK,
    );
    lockAcquired = Number(lockRows[0]?.acquired) === 1;
    if (!lockAcquired) throw new Error("Timed out waiting for the database migration lock.");

    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS \`_senderwho_migrations\` (
        \`name\` VARCHAR(191) NOT NULL,
        \`checksum\` VARCHAR(64) NOT NULL,
        \`appliedAt\` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
        PRIMARY KEY (\`name\`)
      ) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
    `);

    const migrationNames = readdirSync(migrationsPath, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name)
      .sort();

    for (const name of migrationNames) {
      const sqlPath = path.join(migrationsPath, name, "migration.sql");
      if (!existsSync(sqlPath)) continue;
      const sql = readFileSync(sqlPath, "utf8");
      const checksum = createHash("sha256").update(sql).digest("hex");
      const rows = await prisma.$queryRawUnsafe<Array<{ checksum: string }>>(
        "SELECT checksum FROM `_senderwho_migrations` WHERE name = ? LIMIT 1",
        name,
      );
      if (rows[0]) {
        if (rows[0].checksum !== checksum) {
          throw new Error(`Applied migration ${name} has been modified.`);
        }
        continue;
      }

      for (const statement of splitSqlStatements(sql)) {
        await prisma.$executeRawUnsafe(statement);
      }
      await prisma.$executeRawUnsafe(
        "INSERT INTO `_senderwho_migrations` (name, checksum) VALUES (?, ?)",
        name,
        checksum,
      );
      console.log(JSON.stringify({ event: "database.migration.applied", name }));
    }
  } finally {
    if (lockAcquired) {
      await prisma.$queryRawUnsafe("SELECT RELEASE_LOCK(?)", MIGRATION_LOCK);
    }
    await prisma.$disconnect();
  }
}

function splitSqlStatements(sql: string): string[] {
  return sql
    .split(";")
    .map((statement) => statement.trim())
    .filter((statement) => statement.length > 0);
}
