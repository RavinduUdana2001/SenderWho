import type { ThrottlerStorage } from "@nestjs/throttler";
import { Prisma } from "@prisma/client";
import { createHash } from "node:crypto";
import { PrismaService } from "../../database/prisma.service";

export class MysqlThrottlerStorage implements ThrottlerStorage {
  constructor(private readonly prisma: PrismaService) {}

  async increment(
    key: string,
    ttl: number,
    limit: number,
    blockDuration: number,
    throttlerName: string,
  ) {
    const trackerHash = createHash("sha256").update(key).digest("hex");
    const databaseKey = `${throttlerName}:${trackerHash}`;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      try {
        return await this.prisma.$transaction(
          async (tx) => {
            const now = new Date();
            const existing = await tx.apiRateLimit.findUnique({
              where: { key: databaseKey },
            });
            const expired = !existing || existing.expiresAt <= now;
            const totalHits = expired ? 1 : existing.totalHits + 1;
            const expiresAt = expired
              ? new Date(now.getTime() + ttl)
              : existing.expiresAt;
            const wasBlocked =
              !expired &&
              existing.blockedUntil != null &&
              existing.blockedUntil > now;
            const isBlocked = wasBlocked || totalHits > limit;
            const blockedUntil = isBlocked
              ? wasBlocked
                ? existing.blockedUntil
                : new Date(now.getTime() + Math.max(blockDuration, ttl))
              : null;
            await tx.apiRateLimit.upsert({
              where: { key: databaseKey },
              create: {
                key: databaseKey,
                totalHits,
                expiresAt,
                blockedUntil,
              },
              update: { totalHits, expiresAt, blockedUntil },
            });
            return {
              totalHits,
              timeToExpire: secondsUntil(expiresAt, now),
              isBlocked,
              timeToBlockExpire: blockedUntil
                ? secondsUntil(blockedUntil, now)
                : 0,
            };
          },
          { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
        );
      } catch (error) {
        if (!isRetryableWriteConflict(error) || attempt === 2) throw error;
      }
    }
    throw new Error("Rate-limit counter could not be updated.");
  }
}

function secondsUntil(value: Date, now: Date) {
  return Math.max(0, Math.ceil((value.getTime() - now.getTime()) / 1_000));
}

function isRetryableWriteConflict(error: unknown) {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    (error.code === "P2034" || error.code === "P2002")
  );
}
