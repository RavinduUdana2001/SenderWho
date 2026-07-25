import { IsNotEmpty, IsString, MaxLength } from "class-validator";

export class CreateUnsubscribeJobDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  senderId: string;
}
