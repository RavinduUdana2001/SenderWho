import { Body, Controller, Get, HttpCode, Post } from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { SearchService } from "./search.service";
import { Throttle } from "@nestjs/throttler";
import { SearchDto } from "./dto/search.dto";

@Controller("search")
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @Get("filters")
  getFilters() {
    return this.searchService.getFilters();
  }

  @Post()
  @Throttle({ default: { limit: 30, ttl: 60_000, blockDuration: 60_000 } })
  @HttpCode(200)
  search(@CurrentUser("id") userId: string, @Body() body: SearchDto) {
    return this.searchService.search(userId, body);
  }
}
