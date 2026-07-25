import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import type { Request } from "express";
import { createHash } from "node:crypto";
import { Observable, from, lastValueFrom } from "rxjs";
import type { AuthUser } from "../../auth/auth-user.interface";
import { IDEMPOTENCY_SCOPE_KEY } from "./idempotent.decorator";
import { IdempotencyService } from "./idempotency.service";

type AuthenticatedRequest = Request & { user?: AuthUser };

@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  constructor(
    private readonly reflector: Reflector,
    private readonly idempotency: IdempotencyService,
  ) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const scope = this.reflector.getAllAndOverride<string>(
      IDEMPOTENCY_SCOPE_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!scope) return next.handle();
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const userId = request.user?.id;
    if (!userId) return next.handle();
    const key = request.header("idempotency-key") ?? undefined;
    const requestHash = createHash("sha256")
      .update(
        JSON.stringify({
          method: request.method,
          path: request.route?.path ?? request.path,
          params: request.params,
          body: request.body,
        }),
      )
      .digest("hex");
    return from(
      this.idempotency.execute(userId, scope, key, requestHash, () =>
        lastValueFrom(next.handle()),
      ),
    );
  }
}
