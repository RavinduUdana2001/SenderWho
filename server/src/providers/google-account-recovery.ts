import { SyncStatus } from "@prisma/client";

export type GoogleAccountRecoveryAction =
  "NONE" | "RETRY" | "RECONNECT" | "CONFIGURE_GOOGLE";

export function getGoogleAccountRecoveryAction(
  syncStatus: SyncStatus | string,
  lastSyncError?: string | null,
): GoogleAccountRecoveryAction {
  if (syncStatus === SyncStatus.READY) return "NONE";

  const error = lastSyncError?.toLowerCase() ?? "";
  if (
    error.includes("oauth client is disabled") ||
    error.includes("oauth credentials are invalid")
  ) {
    return "CONFIGURE_GOOGLE";
  }

  if (
    syncStatus === SyncStatus.DISCONNECTED ||
    error.includes("reconnect") ||
    error.includes("revoked") ||
    error.includes("no refresh token") ||
    error.includes("encrypted token") ||
    error.includes("encryption key") ||
    error.includes("authenticate data")
  ) {
    return "RECONNECT";
  }

  if (syncStatus === SyncStatus.FAILED) return "RETRY";
  return "NONE";
}
