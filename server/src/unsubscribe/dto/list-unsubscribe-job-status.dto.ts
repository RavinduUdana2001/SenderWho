import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsString,
  MaxLength,
} from "class-validator";

export class ListUnsubscribeJobStatusDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(25)
  @ArrayUnique()
  @IsString({ each: true })
  @MaxLength(100, { each: true })
  jobIds: string[];
}
