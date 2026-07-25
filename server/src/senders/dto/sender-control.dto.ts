import { IsBoolean, IsOptional } from "class-validator";

export class SenderBlockDto {
  @IsOptional()
  @IsBoolean()
  blocked?: boolean;
}

export class SenderTrustDto {
  @IsOptional()
  @IsBoolean()
  trusted?: boolean;
}
