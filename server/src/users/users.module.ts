import { Module } from "@nestjs/common";
import { UsersService } from "./users.service";
import { UsersController } from "./users.controller";
import { TokenEncryptionService } from "../common/security/token-encryption.service";
import { DataRetentionService } from "./data-retention.service";

@Module({
  controllers: [UsersController],
  providers: [UsersService, TokenEncryptionService, DataRetentionService],
  exports: [UsersService],
})
export class UsersModule {}
