import { Global, Module } from "@nestjs/common";
import { TokenEncryptionService } from "../common/security/token-encryption.service";
import { GmailClient } from "./gmail/gmail.client";
import { GmailSyncService } from "./gmail/gmail-sync.service";
import { SenderIdentityRiskService } from "./gmail/sender-identity-risk.service";
import { GoogleTokenService } from "./google-token.service";
import { YahooImapClient } from "./yahoo/yahoo-imap.client";
import { YahooSyncService } from "./yahoo/yahoo-sync.service";
import { YahooTokenService } from "./yahoo/yahoo-token.service";

@Global()
@Module({
  providers: [
    GmailClient,
    GmailSyncService,
    SenderIdentityRiskService,
    GoogleTokenService,
    TokenEncryptionService,
    YahooImapClient,
    YahooSyncService,
    YahooTokenService,
  ],
  exports: [
    GmailClient,
    GmailSyncService,
    SenderIdentityRiskService,
    GoogleTokenService,
    TokenEncryptionService,
    YahooImapClient,
    YahooSyncService,
    YahooTokenService,
  ],
})
export class EmailProvidersModule {}
