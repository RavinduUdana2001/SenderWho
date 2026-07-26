import { JobStatus, Prisma } from "@prisma/client";
import { Injectable, Logger } from "@nestjs/common";
import { lookup } from "node:dns/promises";
import { request as httpsRequest } from "node:https";
import { BlockList, isIP, LookupFunction } from "node:net";
import { PrismaService } from "../database/prisma.service";
import { ProcessorJob } from "./database-job-queue.service";

const BLOCKED_ADDRESSES = new BlockList();
for (const [network, prefix] of [
  ["0.0.0.0", 8],
  ["10.0.0.0", 8],
  ["100.64.0.0", 10],
  ["127.0.0.0", 8],
  ["169.254.0.0", 16],
  ["172.16.0.0", 12],
  ["192.0.0.0", 24],
  ["192.0.2.0", 24],
  ["192.168.0.0", 16],
  ["198.18.0.0", 15],
  ["198.51.100.0", 24],
  ["203.0.113.0", 24],
  ["224.0.0.0", 4],
] as const) {
  BLOCKED_ADDRESSES.addSubnet(network, prefix, "ipv4");
}
for (const [network, prefix] of [
  ["::", 128],
  ["::1", 128],
  ["fc00::", 7],
  ["fe80::", 10],
  ["ff00::", 8],
  ["2001:2::", 48],
  ["2001:db8::", 32],
] as const) {
  BLOCKED_ADDRESSES.addSubnet(network, prefix, "ipv6");
}

@Injectable()
export class UnsubscribeProcessor {
  private readonly logger = new Logger(UnsubscribeProcessor.name);

  constructor(private readonly prisma: PrismaService) {}

  async process(job: ProcessorJob<{ unsubscribeJobId: string }>) {
    const unsubscribeJob = await this.prisma.unsubscribeJob.findUniqueOrThrow({
      where: { id: job.data.unsubscribeJobId },
    });
    if (
      unsubscribeJob.status === JobStatus.COMPLETED ||
      unsubscribeJob.status === JobStatus.CANCELED
    ) {
      return {
        unsubscribeJobId: unsubscribeJob.id,
        status: unsubscribeJob.status,
      };
    }
    if (!unsubscribeJob.unsubscribeUrl) {
      throw new Error("Unsubscribe job has no URL.");
    }

    const previousMetadata = this.metadataObject(unsubscribeJob.metadata);
    if (typeof previousMetadata.providerAttemptedAt === "string") {
      const error =
        "The previous provider response is unknown. Review before retrying.";
      await this.prisma.unsubscribeJob.update({
        where: { id: unsubscribeJob.id },
        data: {
          status: JobStatus.FAILED,
          completedAt: new Date(),
          metadata: this.mergeMetadata(unsubscribeJob.metadata, {
            error,
            outcomeUnknown: 1,
          }),
        },
      });
      await this.safeAudit(
        unsubscribeJob.userId,
        unsubscribeJob.id,
        "unsubscribe.job.outcome_unknown",
      );
      return {
        unsubscribeJobId: unsubscribeJob.id,
        status: JobStatus.FAILED,
        outcomeUnknown: true,
      };
    }

    const providerAttemptedAt = new Date().toISOString();
    const attemptedMetadata = this.mergeMetadata(unsubscribeJob.metadata, {
      providerAttemptedAt,
    });
    await this.prisma.unsubscribeJob.update({
      where: { id: unsubscribeJob.id },
      data: {
        status: JobStatus.RUNNING,
        completedAt: null,
        metadata: attemptedMetadata,
      },
    });

    const eligibleJob = await this.prisma.unsubscribeJob.findFirst({
      where: {
        id: unsubscribeJob.id,
        status: JobStatus.RUNNING,
        user: { deletedAt: null },
        sender: { emailAccount: { syncStatus: { not: "DISCONNECTED" } } },
      },
      select: { id: true },
    });
    if (!eligibleJob) {
      await this.prisma.unsubscribeJob.updateMany({
        where: { id: unsubscribeJob.id, status: JobStatus.RUNNING },
        data: { status: JobStatus.CANCELED, completedAt: new Date() },
      });
      return {
        unsubscribeJobId: unsubscribeJob.id,
        status: JobStatus.CANCELED,
      };
    }

    try {
      const providerStatus = await this.postOneClick(
        unsubscribeJob.unsubscribeUrl,
      );
      await this.prisma.unsubscribeJob.update({
        where: { id: unsubscribeJob.id },
        data: {
          status: JobStatus.COMPLETED,
          completedAt: new Date(),
          metadata: this.mergeMetadata(attemptedMetadata, {
            providerStatus,
          }),
        },
      });
      await this.safeAudit(
        unsubscribeJob.userId,
        unsubscribeJob.id,
        "unsubscribe.job.completed",
        { providerStatus },
      );
      return { unsubscribeJobId: unsubscribeJob.id, providerStatus };
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message.slice(0, 500) : "Unknown error";
      await this.prisma.unsubscribeJob.update({
        where: { id: unsubscribeJob.id },
        data: {
          status: JobStatus.FAILED,
          completedAt: new Date(),
          metadata: this.mergeMetadata(attemptedMetadata, {
            error: errorMessage,
            attempt: job.attemptsMade + 1,
          }),
        },
      });
      await this.safeAudit(
        unsubscribeJob.userId,
        unsubscribeJob.id,
        "unsubscribe.job.failed",
      );
      throw error;
    }
  }

  protected async postOneClick(sourceUrl: string): Promise<number> {
    let currentUrl = new URL(sourceUrl);

    for (let redirect = 0; redirect <= 3; redirect += 1) {
      const target = await this.assertSafePublicHttpsUrl(currentUrl);
      const response = await this.postPinned(currentUrl, target);

      if (response.status >= 200 && response.status < 300) {
        return response.status;
      }

      const location = response.location;
      if (response.status >= 300 && response.status < 400 && location) {
        if (redirect === 3) throw new Error("Too many unsubscribe redirects.");
        currentUrl = new URL(location, currentUrl);
        continue;
      }

      throw new Error(
        `Unsubscribe endpoint returned status ${response.status}.`,
      );
    }

    throw new Error("Unsubscribe request could not be completed.");
  }

  private async assertSafePublicHttpsUrl(url: URL) {
    if (
      url.protocol !== "https:" ||
      url.username ||
      url.password ||
      (url.port && url.port !== "443")
    ) {
      throw new Error("Only public HTTPS unsubscribe URLs are allowed.");
    }

    const addresses = isIP(url.hostname)
      ? [{ address: url.hostname }]
      : await lookup(url.hostname, { all: true, verbatim: true });
    if (
      addresses.length === 0 ||
      addresses.some(({ address }) => isPrivateOrReservedAddress(address))
    ) {
      throw new Error("Private network unsubscribe URLs are not allowed.");
    }
    // Shared production hosts frequently resolve IPv6 first without having a
    // working outbound IPv6 route. Prefer IPv4 when the provider publishes it,
    // while retaining the DNS pinning and private-address rejection above.
    const selected = preferredPublicAddress(addresses);
    return {
      address: selected.address,
      family: isIP(selected.address) as 4 | 6,
    };
  }

  private postPinned(
    url: URL,
    target: { address: string; family: 4 | 6 },
  ): Promise<{ status: number; location?: string }> {
    return new Promise((resolve, reject) => {
      const request = httpsRequest(
        url,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "Content-Length": Buffer.byteLength("List-Unsubscribe=One-Click"),
            "User-Agent": "SenderWho-Unsubscribe/1.0",
          },
          lookup: pinnedLookup(target),
        },
        (response) => {
          const status = response.statusCode ?? 502;
          const rawLocation = response.headers.location;
          const location = Array.isArray(rawLocation)
            ? rawLocation[0]
            : rawLocation;
          response.destroy();
          resolve({ status, location });
        },
      );
      request.setTimeout(15_000, () =>
        request.destroy(new Error("Unsubscribe request timed out.")),
      );
      request.once("error", reject);
      request.end("List-Unsubscribe=One-Click");
    });
  }

  private mergeMetadata(
    metadata: Prisma.JsonValue | Prisma.InputJsonObject | null,
    additional: Record<string, string | number>,
  ): Prisma.InputJsonObject {
    const current =
      metadata && typeof metadata === "object" && !Array.isArray(metadata)
        ? metadata
        : {};
    return { ...current, ...additional } as Prisma.InputJsonObject;
  }

  private metadataObject(metadata: Prisma.JsonValue | null) {
    return metadata && typeof metadata === "object" && !Array.isArray(metadata)
      ? metadata
      : {};
  }

  private async safeAudit(
    userId: string,
    unsubscribeJobId: string,
    action: string,
    metadata?: Record<string, string | number>,
  ) {
    try {
      await this.prisma.auditLog.create({
        data: {
          userId,
          action,
          targetType: "UnsubscribeJob",
          targetId: unsubscribeJobId,
          metadata,
        },
      });
    } catch (error) {
      this.logger.error(
        JSON.stringify({
          event: "unsubscribe.audit.failed",
          targetId: unsubscribeJobId,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        }),
      );
    }
  }
}

export function preferredPublicAddress<T extends { address: string }>(
  addresses: T[],
): T {
  return addresses.find(({ address }) => isIP(address) === 4) ?? addresses[0];
}

export function pinnedLookup(target: {
  address: string;
  family: 4 | 6;
}): LookupFunction {
  return (_hostname, options, callback) => {
    if (options.all) {
      callback(null, [target]);
      return;
    }
    callback(null, target.address, target.family);
  };
}

export function isPrivateOrReservedAddress(address: string): boolean {
  const normalized = address.toLowerCase();
  if (normalized.includes(":")) {
    const mapped = normalized.match(/::ffff:(\d+\.\d+\.\d+\.\d+)$/)?.[1];
    return mapped
      ? isPrivateOrReservedAddress(mapped)
      : isIP(normalized) !== 6 || BLOCKED_ADDRESSES.check(normalized, "ipv6");
  }
  return isIP(normalized) !== 4 || BLOCKED_ADDRESSES.check(normalized, "ipv4");
}
