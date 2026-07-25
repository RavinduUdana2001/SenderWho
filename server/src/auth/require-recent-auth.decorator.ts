import { SetMetadata } from "@nestjs/common";

export const RECENT_AUTH_MAX_AGE_SECONDS_KEY = "recentAuthMaxAgeSeconds";

export const RequireRecentAuth = (maxAgeSeconds = 10 * 60) =>
  SetMetadata(RECENT_AUTH_MAX_AGE_SECONDS_KEY, maxAgeSeconds);
