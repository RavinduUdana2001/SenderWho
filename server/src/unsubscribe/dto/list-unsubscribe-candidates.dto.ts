import { IsIn, IsOptional, IsString, MaxLength } from "class-validator";
import { PaginationDto } from "../../common/dto/pagination.dto";

export class ListUnsubscribeCandidatesDto extends PaginationDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  query?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  emailAccountId?: string;

  @IsOptional()
  @IsIn(["ALL", "ACTIVE", "RETRY"])
  filter: "ALL" | "ACTIVE" | "RETRY" = "ALL";
}
