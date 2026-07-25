import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsString,
  MaxLength,
} from "class-validator";

export class CreateUnsubscribeJobsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(25)
  @ArrayUnique()
  @IsString({ each: true })
  @MaxLength(100, { each: true })
  senderIds: string[];
}
