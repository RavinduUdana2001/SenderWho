import { IsString, Length, Matches } from "class-validator";

export class ExchangeOAuthSessionDto {
  @IsString()
  @Length(10, 100)
  @Matches(/^[A-Za-z0-9_-]+$/)
  sessionId: string;

  @IsString()
  @Length(40, 200)
  @Matches(/^[A-Za-z0-9_-]+$/)
  sessionSecret: string;
}
