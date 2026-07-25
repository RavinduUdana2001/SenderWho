import { Global, Module } from "@nestjs/common";
import { PrismaService } from "./prisma.service";
import { IdempotencyService } from "../common/security/idempotency.service";

@Global()
@Module({
  providers: [PrismaService, IdempotencyService],
  exports: [PrismaService, IdempotencyService],
})
export class DatabaseModule {}
