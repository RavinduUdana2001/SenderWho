import { SetMetadata } from "@nestjs/common";

export const IDEMPOTENCY_SCOPE_KEY = "idempotencyScope";
export const Idempotent = (scope: string) =>
  SetMetadata(IDEMPOTENCY_SCOPE_KEY, scope);
