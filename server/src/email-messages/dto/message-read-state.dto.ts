import { IsBoolean } from "class-validator";
import { BulkMessageActionDto } from "./bulk-message-action.dto";

export class MessageReadStateDto extends BulkMessageActionDto {
  @IsBoolean()
  isRead: boolean;
}
