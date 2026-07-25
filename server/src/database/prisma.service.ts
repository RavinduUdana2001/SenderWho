import { Injectable, OnModuleDestroy, OnModuleInit } from "@nestjs/common";
import { PrismaClient } from "@prisma/client";

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  readonly mockDataEnabled = process.env.MOCK_DATA_ENABLED === "true";

  async onModuleInit() {
    if (this.mockDataEnabled) return;
    await this.$connect();
  }

  async onModuleDestroy() {
    if (this.mockDataEnabled) return;
    await this.$disconnect();
  }
}
