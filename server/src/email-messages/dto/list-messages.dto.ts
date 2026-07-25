import { Transform } from "class-transformer";
import { CleanupCategory, SenderCategory } from "@prisma/client";
import {
  IsBoolean,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
} from "class-validator";
import { PaginationDto } from "../../common/dto/pagination.dto";

export enum MessageMailbox {
  INBOX = "INBOX",
  ALL = "ALL",
  UNREAD = "UNREAD",
  READ = "READ",
  ARCHIVED = "ARCHIVED",
  TRASH = "TRASH",
}

export class ListMessagesDto extends PaginationDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  query?: string;

  @IsOptional()
  @IsEnum(SenderCategory)
  category?: SenderCategory;

  @IsOptional()
  @IsEnum(CleanupCategory)
  cleanupCategory?: CleanupCategory;

  @IsOptional()
  @IsEnum(MessageMailbox)
  mailbox: MessageMailbox = MessageMailbox.INBOX;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  senderId?: string;

  @IsOptional()
  @Transform(({ value }) => {
    if (value === "true" || value === true) return true;
    if (value === "false" || value === false) return false;
    return value;
  })
  @IsBoolean()
  hasAttachments?: boolean;
}
