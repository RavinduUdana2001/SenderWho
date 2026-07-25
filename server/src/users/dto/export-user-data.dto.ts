import { Type } from "class-transformer";
import { IsIn, IsInt, IsOptional, Max, Min } from "class-validator";

export class ExportUserDataDto {
  @IsIn(["profile", "accounts", "senders", "messages", "alerts", "audit"])
  section:
    "profile" | "accounts" | "senders" | "messages" | "alerts" | "audit" =
    "profile";

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(250)
  limit = 100;
}
