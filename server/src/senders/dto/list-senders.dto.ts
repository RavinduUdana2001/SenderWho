import { IsEnum, IsOptional, IsString, MaxLength } from "class-validator";
import { PaginationDto } from "../../common/dto/pagination.dto";
import { SenderCategory } from "@prisma/client";

export enum SenderKind {
  ALL = "ALL",
  PEOPLE = "PEOPLE",
  COMPANIES = "COMPANIES",
  NEWSLETTERS = "NEWSLETTERS",
}

export enum SenderControl {
  ALL = "ALL",
  BLOCKED = "BLOCKED",
  TRUSTED = "TRUSTED",
}

export class ListSendersDto extends PaginationDto {
  @IsOptional()
  @IsString()
  @MaxLength(64)
  emailAccountId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  query?: string;

  @IsOptional()
  @IsEnum(SenderCategory)
  category?: SenderCategory;

  @IsOptional()
  @IsEnum(SenderKind)
  kind: SenderKind = SenderKind.ALL;

  @IsOptional()
  @IsEnum(SenderControl)
  control: SenderControl = SenderControl.ALL;
}
