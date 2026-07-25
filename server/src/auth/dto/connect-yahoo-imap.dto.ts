import { IsEmail, IsString, MaxLength, MinLength } from "class-validator";

export class ConnectYahooImapDto {
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @IsString()
  @MinLength(12)
  @MaxLength(80)
  appPassword!: string;
}
