import {
  BadRequestException,
  ConflictException,
  Injectable,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { PrismaService } from "../../database/prisma.service";

@Injectable()
export class IdempotencyService {
  constructor(private readonly prisma: PrismaService) {}

  async execute<T>(
    userId: string,
    scope: string,
    key: string | undefined,
    requestHash: string,
    operation: () => Promise<T>,
  ): Promise<T> {
    if (!key || !/^[A-Za-z0-9_-]{20,200}$/.test(key)) {
      throw new BadRequestException(
        "A valid Idempotency-Key header is required for this action.",
      );
    }
    const existing = await this.prisma.idempotencyRecord.findUnique({
      where: { userId_scope_key: { userId, scope, key } },
    });
    if (existing) {
      if (existing.expiresAt <= new Date()) {
        await this.prisma.idempotencyRecord.deleteMany({
          where: { id: existing.id, expiresAt: { lte: new Date() } },
        });
      } else {
        if (existing.requestHash !== requestHash) {
          throw new ConflictException(
            "The idempotency key was already used for a different request.",
          );
        }
        if (existing.status === "COMPLETED") return existing.response as T;
        throw new ConflictException(
          "This operation is already running or previously failed.",
        );
      }
    }

    await this.prisma.idempotencyRecord.deleteMany({
      where: { expiresAt: { lt: new Date() } },
    });
    try {
      await this.prisma.idempotencyRecord.create({
        data: {
          userId,
          scope,
          key,
          requestHash,
          expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1_000),
        },
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        throw new ConflictException("This operation is already running.");
      }
      throw error;
    }

    try {
      const result = await operation();
      const response = JSON.parse(
        JSON.stringify(result ?? {}),
      ) as Prisma.InputJsonValue;
      await this.prisma.idempotencyRecord.update({
        where: { userId_scope_key: { userId, scope, key } },
        data: { status: "COMPLETED", response },
      });
      return result;
    } catch (error) {
      await this.prisma.idempotencyRecord.updateMany({
        where: { userId, scope, key, status: "PENDING" },
        data: { status: "FAILED" },
      });
      throw error;
    }
  }
}
