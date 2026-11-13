import { Global, Module } from "@nestjs/common";
import { BackgroundHealthService } from "../common/background-health.service";
import { PrismaService } from "./prisma.service";
import { IdempotencyService } from "../common/security/idempotency.service";

@Global()
@Module({
  providers: [PrismaService, IdempotencyService, BackgroundHealthService],
  exports: [PrismaService, IdempotencyService, BackgroundHealthService],
})
export class DatabaseModule {}
