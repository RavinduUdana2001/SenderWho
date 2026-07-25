import { Injectable } from "@nestjs/common";

@Injectable()
export class ImapClient {
  listMessageMetadata() {
    return {
      provider: "imap",
      note: "Use only as a fallback for providers without supported APIs.",
    };
  }
}
