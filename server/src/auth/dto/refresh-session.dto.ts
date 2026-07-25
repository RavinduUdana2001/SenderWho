import { IsString, Length, Matches } from "class-validator";

export class RefreshSessionDto {
  @IsString()
  @Length(40, 200)
  @Matches(/^[A-Za-z0-9_-]+$/)
  refreshToken: string;
}
