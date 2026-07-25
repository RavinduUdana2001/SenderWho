import {
  ArrayMaxSize,
  ArrayNotEmpty,
  IsArray,
  IsString,
  MaxLength,
} from "class-validator";

export class PreviewCleanupDto {
  @IsString()
  @MaxLength(100)
  emailAccountId: string;

  @IsArray()
  @ArrayNotEmpty()
  @ArrayMaxSize(5)
  @IsString({ each: true })
  @MaxLength(50, { each: true })
  categories: string[];
}
