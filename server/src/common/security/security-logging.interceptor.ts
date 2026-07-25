import {
  CallHandler,
  ExecutionContext,
  HttpException,
  Injectable,
  Logger,
  NestInterceptor,
} from "@nestjs/common";
import type { Request, Response } from "express";
import { createHash, randomUUID } from "node:crypto";
import { Observable, catchError, tap, throwError } from "rxjs";
import type { AuthUser } from "../../auth/auth-user.interface";

type RequestWithUser = Request & { user?: AuthUser; correlationId?: string };

@Injectable()
export class SecurityLoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger("HttpSecurity");

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest<RequestWithUser>();
    const response = context.switchToHttp().getResponse<Response>();
    const correlationId = this.correlationId(request.header("x-request-id"));
    const deviceHash = this.deviceHash(request.header("x-senderwho-device-id"));
    const startedAt = Date.now();
    request.correlationId = correlationId;
    response.setHeader("X-Request-Id", correlationId);

    return next.handle().pipe(
      tap(() => {
        this.logger.log(
          JSON.stringify({
            event: "http.request.completed",
            correlationId,
            method: request.method,
            route: request.route?.path ?? request.path,
            statusCode: response.statusCode,
            durationMs: Date.now() - startedAt,
            actorUserId: request.user?.id,
            actorSessionId: request.user?.sessionId,
            deviceHash,
          }),
        );
      }),
      catchError((error: unknown) => {
        const statusCode =
          error instanceof HttpException ? error.getStatus() : 500;
        const securityEvent = statusCode === 401 || statusCode === 403;
        const record = JSON.stringify({
          event: securityEvent
            ? "security.request.rejected"
            : "http.request.failed",
          correlationId,
          method: request.method,
          route: request.route?.path ?? request.path,
          statusCode,
          durationMs: Date.now() - startedAt,
          actorUserId: request.user?.id,
          actorSessionId: request.user?.sessionId,
          deviceHash,
          errorType:
            error instanceof Error ? error.constructor.name : "UnknownError",
        });
        if (statusCode >= 500) this.logger.error(record);
        else this.logger.warn(record);
        return throwError(() => error);
      }),
    );
  }

  private correlationId(value: string | undefined) {
    return value && /^[A-Za-z0-9._-]{8,128}$/.test(value)
      ? value
      : randomUUID();
  }

  private deviceHash(value: string | undefined) {
    if (!value || !/^[A-Za-z0-9_-]{20,200}$/.test(value)) return undefined;
    return createHash("sha256").update(value).digest("hex").slice(0, 24);
  }
}
