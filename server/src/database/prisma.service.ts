import { Injectable, OnModuleDestroy, OnModuleInit } from "@nestjs/common";
import { PrismaClient } from "@prisma/client";
import { createPrismaAdapter } from "./prisma-adapter";

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  readonly mockDataEnabled = process.env.MOCK_DATA_ENABLED === "true";

  constructor() {
    super({ adapter: createPrismaAdapter() });
  }

  async onModuleInit() {
    if (this.mockDataEnabled) return;
    console.log(
      JSON.stringify({
        event: "database.prisma_connection.starting",
        engine: "client",
        adapter: "mariadb",
      }),
    );
    await this.$connect();
    console.log(
      JSON.stringify({ event: "database.prisma_connection.succeeded" }),
    );
  }

  async onModuleDestroy() {
    if (this.mockDataEnabled) return;
    await this.$disconnect();
  }
}
