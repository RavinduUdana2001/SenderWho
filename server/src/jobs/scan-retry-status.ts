import { PrismaService } from "../database/prisma.service";

export const scanJobId = (emailAccountId: string) =>
  `scan-inbox-scan-${emailAccountId}`;

/** Call only with account IDs already scoped to the authenticated owner. */
export async function queuedScanRetries(
  prisma: PrismaService,
  accountIds: string[],
) {
  if (accountIds.length === 0) return new Map<string, Date>();
  const jobs = await prisma.backgroundJob.findMany({
    where: {
      id: { in: accountIds.map(scanJobId) },
      queue: "scan-inbox",
      status: "QUEUED",
    },
    select: { id: true, availableAt: true },
  });
  return new Map(jobs.map((job) => [job.id, job.availableAt]));
}
