import { IsString, MaxLength } from "class-validator";
import { PreviewCleanupDto } from "./preview-cleanup.dto";

export class CreateCleanupJobDto extends PreviewCleanupDto {
  @IsString()
  @MaxLength(100)
  previewId: string;
}
