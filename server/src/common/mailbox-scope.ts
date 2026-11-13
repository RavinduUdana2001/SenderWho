import { SyncStatus } from "@prisma/client";

/** Mailbox views follow the selected account while retaining user ownership. */
export function mailboxScope(userId: string, emailAccountId?: string) {
  return {
    userId,
    ...(emailAccountId ? { emailAccountId } : {}),
    emailAccount: {
      userId,
      ...(emailAccountId ? {} : { isPrimary: true }),
      syncStatus: { not: SyncStatus.DISCONNECTED },
    },
  };
}
