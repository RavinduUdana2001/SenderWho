import "reflect-metadata";
import { ServiceUnavailableException } from "@nestjs/common";
import { HealthController, READINESS_TIMEOUT_MS } from "./health.controller";

describe("HealthController", () => {
  afterEach(() => {
    jest.useRealTimers();
  });

  it("keeps liveness process-only", () => {
    const prisma = {
      mockDataEnabled: false,
      $queryRaw: jest.fn(),
    };
    const jobs = { countRunnable: jest.fn() };
    const controller = new HealthController(prisma as never, jobs as never);

    expect(controller.getHealth()).toMatchObject({
      status: "ok",
      service: "senderwho-server",
    });
    expect(controller.getLiveness()).toMatchObject({
      status: "ok",
      service: "senderwho-server",
    });
    expect(prisma.$queryRaw).not.toHaveBeenCalled();
    expect(jobs.countRunnable).not.toHaveBeenCalled();
  });

  it("reports ready after MySQL and the durable job table respond", async () => {
    const prisma = {
      mockDataEnabled: false,
      $queryRaw: jest.fn().mockResolvedValue([{ ready: 1 }]),
    };
    const jobs = { countRunnable: jest.fn().mockResolvedValue(0) };
    const controller = new HealthController(prisma as never, jobs as never);

    await expect(controller.getReadiness()).resolves.toMatchObject({
      status: "ready",
      service: "senderwho-server",
      components: {
        mysql: { status: "up" },
        databaseQueue: { status: "up" },
      },
    });
    expect(prisma.$queryRaw).toHaveBeenCalledTimes(1);
    expect(jobs.countRunnable).toHaveBeenCalledTimes(1);
  });

  it("returns a sanitized 503 response when a dependency is unavailable", async () => {
    const prisma = {
      mockDataEnabled: false,
      $queryRaw: jest
        .fn()
        .mockRejectedValue(new Error("mysql://user:secret@private-host/db")),
    };
    const jobs = { countRunnable: jest.fn().mockResolvedValue(0) };
    const controller = new HealthController(prisma as never, jobs as never);

    const error = await controller.getReadiness().catch((caught) => caught);

    expect(error).toBeInstanceOf(ServiceUnavailableException);
    expect(error.getStatus()).toBe(503);
    expect(error.getResponse()).toMatchObject({
      status: "unready",
      components: {
        mysql: { status: "down", reason: "unavailable" },
        databaseQueue: { status: "up" },
      },
    });
    expect(JSON.stringify(error.getResponse())).not.toContain("secret");
    expect(JSON.stringify(error.getResponse())).not.toContain("private-host");
  });

  it("bounds a stalled dependency check and reports a timeout", async () => {
    jest.useFakeTimers();
    const prisma = {
      mockDataEnabled: false,
      $queryRaw: jest.fn().mockResolvedValue([{ ready: 1 }]),
    };
    const jobs = {
      countRunnable: jest.fn().mockReturnValue(new Promise(() => undefined)),
    };
    const controller = new HealthController(prisma as never, jobs as never);
    const readiness = controller.getReadiness().catch((caught) => caught);

    await jest.advanceTimersByTimeAsync(READINESS_TIMEOUT_MS);
    const error = await readiness;

    expect(error).toBeInstanceOf(ServiceUnavailableException);
    expect(error.getStatus()).toBe(503);
    expect(error.getResponse()).toMatchObject({
      status: "unready",
      components: {
        mysql: { status: "up" },
        databaseQueue: { status: "down", reason: "timeout" },
      },
    });
  });

  it("is ready without external dependencies only in explicit mock mode", async () => {
    const prisma = {
      mockDataEnabled: true,
      $queryRaw: jest.fn(),
    };
    const jobs = { countRunnable: jest.fn() };
    const controller = new HealthController(prisma as never, jobs as never);

    await expect(controller.getReadiness()).resolves.toMatchObject({
      status: "ready",
      components: {
        mysql: { status: "skipped" },
        databaseQueue: { status: "skipped" },
      },
    });
    expect(prisma.$queryRaw).not.toHaveBeenCalled();
    expect(jobs.countRunnable).not.toHaveBeenCalled();
  });
});
