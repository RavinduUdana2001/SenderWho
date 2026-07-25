import { Injectable } from "@nestjs/common";

@Injectable()
export class MicrosoftGraphClient {
  listMessageMetadata(_accessToken: string) {
    return {
      provider: "microsoft-graph",
      note: "Implement Microsoft Graph /me/messages metadata sync here.",
    };
  }
}
