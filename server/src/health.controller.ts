import { Controller, Get, ServiceUnavailableException } from "@nestjs/common";
import { Public } from "./auth/public.decorator";
import { PrismaService } from "./database/prisma.service";
import { DatabaseJobQueueService } from "./jobs/database-job-queue.service";

export const READINESS_TIMEOUT_MS = 1_000;

type ComponentStatus = {
  status: "up" | "down" | "skipped";
  reason?: "timeout" | "unavailable";
};

class ReadinessTimeoutError extends Error {}

@Controller("health")
@Public()
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jobs: DatabaseJobQueueService,
  ) {}

  @Get()
  getHealth() {
    return this.livenessResponse();
  }

  @Get("live")
  getLiveness() {
    return this.livenessResponse();
  }

  @Get("ready")
  async getReadiness() {
    if (this.prisma.mockDataEnabled) {
      return this.readinessResponse("ready", {
        mysql: { status: "skipped" },
        databaseQueue: { status: "skipped" },
      });
    }

    const [mysql, databaseQueue] = await Promise.all([
      this.checkComponent(async () => {
        await this.prisma.$queryRaw`SELECT 1`;
      }),
      this.checkComponent(async () => {
        await this.jobs.countRunnable();
      }),
    ]);
    const components = { mysql, databaseQueue };
    const ready = Object.values(components).every(
      (component) => component.status === "up",
    );
    const response = this.readinessResponse(
      ready ? "ready" : "unready",
      components,
    );
    if (!ready) throw new ServiceUnavailableException(response);
    return response;
  }

  private livenessResponse() {
    return {
      status: "ok",
      service: "senderwho-server",
      timestamp: new Date().toISOString(),
    };
  }

  private readinessResponse(
    status: "ready" | "unready",
    components: Record<string, ComponentStatus>,
  ) {
    return {
      status,
      service: "senderwho-server",
      timestamp: new Date().toISOString(),
      components,
    };
  }

  private async checkComponent(
    check: () => Promise<void>,
  ): Promise<ComponentStatus> {
    try {
      await withTimeout(check(), READINESS_TIMEOUT_MS);
      return { status: "up" };
    } catch (error) {
      return {
        status: "down",
        reason:
          error instanceof ReadinessTimeoutError ? "timeout" : "unavailable",
      };
    }
  }
}

async function withTimeout<T>(operation: Promise<T>, timeoutMs: number) {
  let timeout: NodeJS.Timeout | undefined;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeout = setTimeout(
      () => reject(new ReadinessTimeoutError("Readiness check timed out")),
      timeoutMs,
    );
    timeout.unref();
  });

  try {
    return await Promise.race([operation, timeoutPromise]);
  } finally {
    if (timeout) clearTimeout(timeout);
  }
}
