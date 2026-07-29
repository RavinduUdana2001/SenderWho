import { Controller, Get, Header } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Public } from "../auth/public.decorator";
import {
  PublicSiteDetails,
  renderDeleteAccountPage,
  renderHomePage,
  renderPrivacyPage,
  renderSupportPage,
  renderTermsPage,
} from "./public-site.pages";

@Public()
@Controller()
export class PublicSiteController {
  constructor(private readonly config: ConfigService) {}

  @Get()
  @Header("Content-Type", "text/html; charset=utf-8")
  home(): string {
    return renderHomePage(this.details());
  }

  @Get("privacy")
  @Header("Content-Type", "text/html; charset=utf-8")
  privacy(): string {
    return renderPrivacyPage(this.details());
  }

  @Get("terms")
  @Header("Content-Type", "text/html; charset=utf-8")
  terms(): string {
    return renderTermsPage(this.details());
  }

  @Get("support")
  @Header("Content-Type", "text/html; charset=utf-8")
  support(): string {
    return renderSupportPage(this.details());
  }

  @Get("delete-account")
  @Header("Content-Type", "text/html; charset=utf-8")
  deleteAccount(): string {
    return renderDeleteAccountPage(this.details());
  }

  private details(): PublicSiteDetails {
    return {
      legalName: this.config.get<string>("publicSite.legalName", "SenderWho"),
      supportEmail: this.config.get<string>("publicSite.supportEmail", ""),
      effectiveDate: this.config.get<string>(
        "publicSite.effectiveDate",
        "2026-07-29",
      ),
    };
  }
}
