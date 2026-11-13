/** A provider cooldown that a durable job must not shorten. */
export class ProviderRetryError extends Error {
  constructor(
    message: string,
    readonly retryAfterMs = 0,
  ) {
    super(message);
  }
}
