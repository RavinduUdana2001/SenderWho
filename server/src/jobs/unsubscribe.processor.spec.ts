import { JobStatus } from "@prisma/client";
import { PrismaService } from "../database/prisma.service";
import {
  UnsubscribeProcessor,
  isPrivateOrReservedAddress,
  pinnedLookup,
} from "./unsubscribe.processor";
import { ProcessorJob } from "./database-job-queue.service";

describe("UnsubscribeProcessor", () => {
  class TestUnsubscribeProcessor extends UnsubscribeProcessor {
    readonly providerPost = jest.fn<Promise<number>, [string]>();

    protected override postOneClick(sourceUrl: string): Promise<number> {
      return this.providerPost(sourceUrl);
    }
  }

  function setup(attemptsMade: number) {
    const prisma = {
      unsubscribeJob: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: "unsubscribe-1",
          userId: "user-1",
          status: JobStatus.QUEUED,
          unsubscribeUrl: "https://127.0.0.1/unsubscribe",
          metadata: null,
        }),
        update: jest.fn().mockResolvedValue({}),
        findFirst: jest.fn().mockResolvedValue({ id: "unsubscribe-1" }),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      auditLog: { create: jest.fn().mockResolvedValue({ id: "audit-1" }) },
    } as unknown as PrismaService;
    const job = {
      data: { unsubscribeJobId: "unsubscribe-1" },
      attemptsMade,
      opts: { attempts: 3 },
    } as unknown as ProcessorJob<{ unsubscribeJobId: string }>;

    return { processor: new UnsubscribeProcessor(prisma), prisma, job };
  }

  it("fails an unsafe provider request without automatic POST replay", async () => {
    const { processor, prisma, job } = setup(0);

    await expect(processor.process(job)).rejects.toThrow(
      "Private network unsubscribe URLs are not allowed.",
    );

    expect(prisma.unsubscribeJob.update).toHaveBeenLastCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          status: JobStatus.FAILED,
          completedAt: expect.any(Date),
        }),
      }),
    );
  });

  it("marks the request failed consistently regardless of Bull attempt count", async () => {
    const { processor, prisma, job } = setup(2);

    await expect(processor.process(job)).rejects.toThrow(
      "Private network unsubscribe URLs are not allowed.",
    );

    expect(prisma.unsubscribeJob.update).toHaveBeenLastCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          status: JobStatus.FAILED,
          completedAt: expect.any(Date),
        }),
      }),
    );
  });

  it("does not turn provider success into a retry when audit logging fails", async () => {
    const prisma = {
      unsubscribeJob: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: "unsubscribe-1",
          userId: "user-1",
          status: JobStatus.QUEUED,
          unsubscribeUrl: "https://public.example/unsubscribe",
          metadata: null,
        }),
        update: jest.fn().mockResolvedValue({}),
        findFirst: jest.fn().mockResolvedValue({ id: "unsubscribe-1" }),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      auditLog: {
        create: jest.fn().mockRejectedValue(new Error("Audit unavailable")),
      },
    } as unknown as PrismaService;
    const processor = new TestUnsubscribeProcessor(prisma);
    processor.providerPost.mockResolvedValue(204);
    const job = {
      data: { unsubscribeJobId: "unsubscribe-1" },
      attemptsMade: 0,
      opts: { attempts: 1 },
    } as unknown as ProcessorJob<{ unsubscribeJobId: string }>;

    await expect(processor.process(job)).resolves.toEqual({
      unsubscribeJobId: "unsubscribe-1",
      providerStatus: 204,
    });
    expect(processor.providerPost).toHaveBeenCalledTimes(1);
    expect(prisma.unsubscribeJob.update).toHaveBeenLastCalledWith({
      where: { id: "unsubscribe-1" },
      data: expect.objectContaining({ status: JobStatus.COMPLETED }),
    });
  });

  it("does not resend a provider POST whose prior outcome is unknown", async () => {
    const prisma = {
      unsubscribeJob: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: "unsubscribe-1",
          userId: "user-1",
          status: JobStatus.RUNNING,
          unsubscribeUrl: "https://public.example/unsubscribe",
          metadata: { providerAttemptedAt: "2026-07-20T00:00:00.000Z" },
        }),
        update: jest.fn().mockResolvedValue({}),
      },
      auditLog: { create: jest.fn().mockResolvedValue({}) },
    } as unknown as PrismaService;
    const processor = new TestUnsubscribeProcessor(prisma);
    const job = {
      data: { unsubscribeJobId: "unsubscribe-1" },
      attemptsMade: 1,
      opts: { attempts: 3 },
    } as unknown as ProcessorJob<{ unsubscribeJobId: string }>;

    await expect(processor.process(job)).resolves.toMatchObject({
      status: JobStatus.FAILED,
      outcomeUnknown: true,
    });
    expect(processor.providerPost).not.toHaveBeenCalled();
  });

  it("cancels before the provider POST when the account was disconnected", async () => {
    const prisma = {
      unsubscribeJob: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: "unsubscribe-1",
          userId: "user-1",
          status: JobStatus.QUEUED,
          unsubscribeUrl: "https://public.example/unsubscribe",
          metadata: null,
        }),
        update: jest.fn().mockResolvedValue({}),
        findFirst: jest.fn().mockResolvedValue(null),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      auditLog: { create: jest.fn().mockResolvedValue({}) },
    } as unknown as PrismaService;
    const processor = new TestUnsubscribeProcessor(prisma);
    const job = {
      data: { unsubscribeJobId: "unsubscribe-1" },
      attemptsMade: 0,
      opts: { attempts: 1 },
    } as unknown as ProcessorJob<{ unsubscribeJobId: string }>;

    await expect(processor.process(job)).resolves.toMatchObject({
      status: JobStatus.CANCELED,
    });
    expect(processor.providerPost).not.toHaveBeenCalled();
  });

  it.each([
    "127.0.0.1",
    "169.254.169.254",
    "192.0.2.1",
    "198.51.100.8",
    "203.0.113.9",
    "::1",
    "fc00::1",
    "fe80::1",
    "ff02::1",
    "2001:db8::1",
    "::ffff:127.0.0.1",
  ])("blocks private or reserved address %s", (address) => {
    expect(isPrivateOrReservedAddress(address)).toBe(true);
  });

  it.each(["8.8.8.8", "1.1.1.1", "2606:4700:4700::1111"])(
    "allows public address %s",
    (address) => {
      expect(isPrivateOrReservedAddress(address)).toBe(false);
    },
  );

  it("returns the pinned address shape requested by modern Node HTTPS", () => {
    const callback = jest.fn();
    pinnedLookup({ address: "1.1.1.1", family: 4 })(
      "public.example",
      { all: true },
      callback,
    );
    expect(callback).toHaveBeenCalledWith(null, [
      { address: "1.1.1.1", family: 4 },
    ]);
  });
});
