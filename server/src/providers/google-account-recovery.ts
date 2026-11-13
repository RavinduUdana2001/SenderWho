import { EmailProvider, SyncStatus } from "@prisma/client";

export type GoogleAccountRecoveryAction =
  "NONE" | "RETRY" | "RECONNECT" | "CONFIGURE_GOOGLE" | "CONTACT_ADMIN";

export function getGoogleAccountRecoveryAction(
  syncStatus: SyncStatus | string,
  lastSyncError?: string | null,
): GoogleAccountRecoveryAction {
  if (syncStatus === SyncStatus.READY) return "NONE";

  const error = lastSyncError?.toLowerCase() ?? "";
  if (
    error.includes("gmail is busy") ||
    error.includes("temporarily limiting") ||
    error.includes("daily api limit")
  )
    return "RETRY";
  if (error.includes("workspace administrator")) return "CONTACT_ADMIN";
  if (
    error.includes("oauth client is disabled") ||
    error.includes("oauth credentials are invalid") ||
    error.includes("gmail api is not enabled")
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
    error.includes("authenticate data") ||
    error.includes("gmail batch item failed with status 403") ||
    error.includes("gmail api request failed with status 403")
  ) {
    return "RECONNECT";
  }

  if (syncStatus === SyncStatus.FAILED) return "RETRY";
  return "NONE";
}

export function getEmailAccountRecoveryAction(
  provider: EmailProvider | string,
  syncStatus: SyncStatus | string,
  lastSyncError?: string | null,
): GoogleAccountRecoveryAction {
  if (provider === EmailProvider.GOOGLE || provider === "GOOGLE") {
    return getGoogleAccountRecoveryAction(syncStatus, lastSyncError);
  }
  if (syncStatus === SyncStatus.READY) return "NONE";

  const error = lastSyncError?.toLowerCase() ?? "";
  if (
    syncStatus === SyncStatus.DISCONNECTED ||
    error.includes("reconnect") ||
    error.includes("revoked") ||
    error.includes("authorization expired") ||
    error.includes("refresh token")
  ) {
    return "RECONNECT";
  }
  if (syncStatus === SyncStatus.FAILED) return "RETRY";
  return "NONE";
}
