import { IsEmail, IsOptional, MaxLength } from "class-validator";

export class StartOAuthDto {
  @IsOptional()
  @IsEmail()
  @MaxLength(254)
  loginHint?: string;
}
