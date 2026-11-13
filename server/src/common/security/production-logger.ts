import { ConsoleLogger } from "@nestjs/common";

// Nest's default exception handler supplies raw errors/stacks to Logger.error.
// Preserve only reviewed structured fields; never forward its raw arguments.
export class ProductionLogger extends ConsoleLogger {
  constructor() {
    super({ forceConsole: true, colors: false });
  }

  error(message: unknown, ..._optionalParams: unknown[]) {
    let record: Record<string, unknown> = { event: "application.error" };
    if (typeof message === "string") {
      try {
        const parsed = JSON.parse(message);
        if (
          parsed &&
          typeof parsed.event === "string" &&
          /^[a-z0-9._]{1,80}$/.test(parsed.event)
        ) {
          record = { event: parsed.event };
          for (const key of [
            "correlationId",
            "method",
            "route",
            "statusCode",
            "durationMs",
            "actorUserId",
            "actorSessionHash",
            "deviceHash",
            "targetId",
            "errorType",
            "disconnected",
            "recoveryAction",
            "queue",
            "attempt",
            "maxAttempts",
          ]) {
            const value = parsed[key];
            if (["string", "number", "boolean"].includes(typeof value))
              record[key] = value;
          }
        }
      } catch {
        // Raw framework/provider errors are represented only by a generic event.
      }
    }
    super.error(JSON.stringify(record), "Production");
  }
}
