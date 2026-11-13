import { BadGatewayException, Injectable } from "@nestjs/common";
import { ProviderRetryError } from "../../common/provider-retry.error";

export interface GmailProfile {
  emailAddress: string;
  historyId?: string;
  messagesTotal?: number;
  threadsTotal?: number;
}

export interface GmailMessageList {
  messages?: Array<{ id: string; threadId: string }>;
  nextPageToken?: string;
  resultSizeEstimate?: number;
}

export interface GmailHistoryList {
  history?: Array<{
    id: string;
    messages?: Array<{ id: string; threadId?: string; labelIds?: string[] }>;
    messagesAdded?: Array<{
      message: { id: string; threadId?: string; labelIds?: string[] };
    }>;
    messagesDeleted?: Array<{
      message: { id: string; threadId?: string; labelIds?: string[] };
    }>;
    labelsAdded?: Array<{
      message: { id: string; threadId?: string; labelIds?: string[] };
      labelIds?: string[];
    }>;
    labelsRemoved?: Array<{
      message: { id: string; threadId?: string; labelIds?: string[] };
      labelIds?: string[];
    }>;
  }>;
  nextPageToken?: string;
  historyId?: string;
}

export interface GmailMessage {
  id: string;
  threadId: string;
  historyId?: string;
  labelIds?: string[];
  snippet?: string;
  internalDate?: string;
  sizeEstimate?: number;
  payload?: {
    mimeType?: string;
    headers?: Array<{ name: string; value: string }>;
    filename?: string;
    body?: { attachmentId?: string; size?: number; data?: string };
    parts?: GmailMessage["payload"][];
  };
}

export interface GmailBatchMessageResult {
  id: string;
  message?: GmailMessage;
  status: number;
  errorReason?: string;
  retryAfterMs?: number;
}

export class GmailApiError extends ProviderRetryError {
  constructor(
    readonly status: number,
    message: string,
    readonly reason?: string,
    retryAfterMs = 0,
  ) {
    super(message, retryAfterMs);
    this.name = "GmailApiError";
  }
}

// Keep provider diagnostics structured; do not expose raw response messages,
// which may contain mailbox identifiers or request details.
export function gmailApiError(
  status: number,
  reason?: string,
  retryAfterMs = 0,
): GmailApiError {
  const limited =
    status === 429 ||
    reason === "rateLimitExceeded" ||
    reason === "userRateLimitExceeded" ||
    reason === "dailyLimitExceeded";
  let message: string;
  switch (reason) {
    case "rateLimitExceeded":
    case "userRateLimitExceeded":
      message =
        "Gmail is busy. Your saved mail is still available. Sync can continue after a short pause.";
      break;
    case "dailyLimitExceeded":
      message =
        "Gmail's daily API limit has been reached. Try scanning later or contact SenderWho support.";
      break;
    case "insufficientPermissions":
    case "ACCESS_TOKEN_SCOPE_INSUFFICIENT":
      message =
        "Gmail access needs to be renewed. Reconnect this mailbox and allow SenderWho to read and manage your mail.";
      break;
    case "accessNotConfigured":
    case "SERVICE_DISABLED":
      message =
        "The SenderWho Gmail API is not enabled. Contact SenderWho support to restore scanning.";
      break;
    case "domainPolicy":
      message =
        "Your Google Workspace administrator does not allow SenderWho to access Gmail. Ask your administrator to allow the app.";
      break;
    default:
      message = limited
        ? "Gmail is busy. Your saved mail is still available. Sync can continue after a short pause."
        : status === 403
          ? "Gmail could not allow access to this mailbox. Reconnect Gmail to review permissions. If it still fails, contact SenderWho support."
          : status === 401
            ? "Gmail access has expired. Reconnect this mailbox to continue scanning."
            : "Gmail could not complete the sync. Your saved mail is still available.";
  }
  return new GmailApiError(
    status,
    message,
    reason,
    limited
      ? Math.max(
          reason === "dailyLimitExceeded" ? 60 * 60_000 : 60_000,
          retryAfterMs,
        )
      : retryAfterMs,
  );
}

export function gmailRetryAfterMs(value: string | null): number {
  if (!value) return 0;
  const seconds = Number(value);
  const delay = Number.isFinite(seconds)
    ? seconds * 1_000
    : Date.parse(value) - Date.now();
  return Number.isFinite(delay)
    ? Math.max(0, Math.min(delay, 24 * 60 * 60_000))
    : 0;
}

function errorReason(payload: unknown): string | undefined {
  if (typeof payload !== "object" || payload === null) return;
  const error = (
    payload as {
      error?: {
        errors?: Array<{ reason?: unknown }>;
        details?: Array<{ reason?: unknown }>;
      };
    }
  ).error;
  const reason =
    error?.errors?.[0]?.reason ??
    error?.details?.find((item) => typeof item.reason === "string")?.reason;
  return typeof reason === "string" && /^[a-zA-Z_]{1,80}$/.test(reason)
    ? reason
    : undefined;
}

function parseErrorReason(source: string): string | undefined {
  try {
    return errorReason(JSON.parse(source));
  } catch {
    return undefined;
  }
}

@Injectable()
export class GmailClient {
  private static readonly maxAttempts = 5;

  getProfile(accessToken: string): Promise<GmailProfile> {
    return this.request<GmailProfile>("/users/me/profile", accessToken);
  }

  listMessages(
    accessToken: string,
    options: {
      maxResults?: number;
      pageToken?: string;
      query?: string;
      includeSpamTrash?: boolean;
    } = {},
  ): Promise<GmailMessageList> {
    const params = new URLSearchParams();
    params.set("maxResults", String(options.maxResults ?? 500));
    if (options.pageToken) params.set("pageToken", options.pageToken);
    if (options.query) params.set("q", options.query);
    if (options.includeSpamTrash) params.set("includeSpamTrash", "true");

    return this.request<GmailMessageList>(
      `/users/me/messages?${params.toString()}`,
      accessToken,
    );
  }

  getMessage(accessToken: string, messageId: string): Promise<GmailMessage> {
    return this.request<GmailMessage>(
      `/users/me/messages/${encodeURIComponent(messageId)}?${this.metadataQuery()}`,
      accessToken,
    );
  }

  async getMessagesBatch(
    accessToken: string,
    messageIds: string[],
  ): Promise<GmailBatchMessageResult[]> {
    if (messageIds.length === 0) return [];
    if (messageIds.length > 50) {
      throw new Error("Gmail metadata batches are limited to 50 messages.");
    }
    const results = new Map<string, GmailBatchMessageResult>();
    let pendingIds = [...messageIds];
    for (
      let attempt = 1;
      attempt <= GmailClient.maxAttempts && pendingIds.length > 0;
      attempt += 1
    ) {
      const batch = await this.requestMessagesBatch(accessToken, pendingIds);
      const retryIds: string[] = [];
      for (const result of batch) {
        if (this.isRetryableStatus(result.status, result.errorReason)) {
          results.set(result.id, result);
          retryIds.push(result.id);
        } else {
          results.set(result.id, result);
        }
      }
      pendingIds = retryIds;
      if (pendingIds.length > 0 && attempt < GmailClient.maxAttempts) {
        const retryAfterMs = Math.max(
          0,
          ...batch.map((item) => item.retryAfterMs ?? 0),
        );
        // Long cooldowns belong in the durable queue, not in a sleeping worker.
        if (retryAfterMs >= 60_000) break;
        await this.waitBeforeRetry(
          attempt,
          retryAfterMs ? String(retryAfterMs / 1_000) : undefined,
        );
      }
    }
    for (const id of pendingIds) {
      results.set(id, results.get(id) ?? { id, status: 429 });
    }
    const ordered = messageIds.map(
      (id) => results.get(id) ?? { id, status: 502 },
    );
    // Let the caller refresh the account token once for an expired batch item.
    if (ordered.some((result) => result.status === 401))
      throw gmailApiError(401);
    return ordered;
  }

  private async requestMessagesBatch(
    accessToken: string,
    messageIds: string[],
  ): Promise<GmailBatchMessageResult[]> {
    const boundary = `senderwho_${crypto.randomUUID().replaceAll("-", "")}`;
    const query = this.metadataQuery();
    const body = [
      ...messageIds.flatMap((id, index) => [
        `--${boundary}`,
        "Content-Type: application/http",
        `Content-ID: <message-${index}>`,
        "",
        `GET /gmail/v1/users/me/messages/${encodeURIComponent(id)}?${query} HTTP/1.1`,
        "",
      ]),
      `--${boundary}--`,
      "",
    ].join("\r\n");

    let response: Response;
    try {
      response = await fetch("https://gmail.googleapis.com/batch/gmail/v1", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": `multipart/mixed; boundary=${boundary}`,
        },
        body,
        signal: AbortSignal.timeout(30_000),
      });
    } catch {
      throw new BadGatewayException("Could not reach the Gmail batch API.");
    }
    if (!response.ok) {
      const reason = parseErrorReason(await response.text());
      if (this.isRetryableStatus(response.status, reason)) {
        return messageIds.map((id) => ({
          id,
          status: response.status,
          errorReason: reason,
          retryAfterMs: gmailRetryAfterMs(response.headers.get("retry-after")),
        }));
      }
      throw gmailApiError(
        response.status,
        reason,
        gmailRetryAfterMs(response.headers.get("retry-after")),
      );
    }

    const contentType = response.headers.get("content-type") ?? "";
    const responseBoundary = contentType
      .match(/boundary="?([^";]+)"?/i)?.[1]
      ?.trim();
    if (!responseBoundary) {
      throw new BadGatewayException(
        "Gmail returned an invalid batch response.",
      );
    }
    const payload = await response.text();
    const parts = payload
      .split(`--${responseBoundary}`)
      .filter((part) => /\bHTTP\/1\.[01]\s+\d{3}\b/.test(part));
    if (parts.length !== messageIds.length) {
      throw new BadGatewayException(
        "Gmail returned an incomplete batch response.",
      );
    }

    return parts.map((part, index) => {
      const status = Number(
        part.match(/\bHTTP\/1\.[01]\s+(\d{3})\b/)?.[1] ?? 502,
      );
      if (status < 200 || status >= 300) {
        const jsonStart = part.indexOf("{", part.indexOf("HTTP/"));
        const jsonEnd = part.lastIndexOf("}");
        return {
          id: messageIds[index],
          status,
          errorReason:
            jsonStart >= 0
              ? parseErrorReason(part.slice(jsonStart, jsonEnd + 1))
              : undefined,
          retryAfterMs: gmailRetryAfterMs(
            part.match(/(?:^|\r?\n)Retry-After:\s*([^\r\n]+)/i)?.[1] ?? null,
          ),
        };
      }
      const jsonStart = part.indexOf("{", part.indexOf("HTTP/"));
      const jsonEnd = part.lastIndexOf("}");
      if (jsonStart < 0 || jsonEnd < jsonStart) {
        return { id: messageIds[index], status: 502 };
      }
      try {
        return {
          id: messageIds[index],
          status,
          message: JSON.parse(
            part.slice(jsonStart, jsonEnd + 1),
          ) as GmailMessage,
        };
      } catch {
        return { id: messageIds[index], status: 502 };
      }
    });
  }

  getMessageContent(
    accessToken: string,
    messageId: string,
  ): Promise<GmailMessage> {
    const params = new URLSearchParams({ format: "full" });
    return this.request<GmailMessage>(
      `/users/me/messages/${encodeURIComponent(messageId)}?${params.toString()}`,
      accessToken,
    );
  }

  listHistory(
    accessToken: string,
    startHistoryId: string,
    pageToken?: string,
  ): Promise<GmailHistoryList> {
    const params = new URLSearchParams({
      startHistoryId,
      maxResults: "500",
    });
    if (pageToken) params.set("pageToken", pageToken);
    return this.request<GmailHistoryList>(
      `/users/me/history?${params.toString()}`,
      accessToken,
    );
  }

  trashMessage(accessToken: string, messageId: string): Promise<GmailMessage> {
    return this.request<GmailMessage>(
      `/users/me/messages/${encodeURIComponent(messageId)}/trash`,
      accessToken,
      { method: "POST" },
    );
  }

  untrashMessage(
    accessToken: string,
    messageId: string,
  ): Promise<GmailMessage> {
    return this.request<GmailMessage>(
      `/users/me/messages/${encodeURIComponent(messageId)}/untrash`,
      accessToken,
      { method: "POST" },
    );
  }

  modifyMessage(
    accessToken: string,
    messageId: string,
    labels: { addLabelIds?: string[]; removeLabelIds?: string[] },
  ): Promise<GmailMessage> {
    return this.request<GmailMessage>(
      `/users/me/messages/${encodeURIComponent(messageId)}/modify`,
      accessToken,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(labels),
      },
    );
  }

  batchModifyMessages(
    accessToken: string,
    messageIds: string[],
    labels: { addLabelIds?: string[]; removeLabelIds?: string[] },
  ): Promise<void> {
    return this.request<void>("/users/me/messages/batchModify", accessToken, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ids: messageIds, ...labels }),
    });
  }

  private async request<T>(
    path: string,
    accessToken: string,
    init: RequestInit = {},
  ): Promise<T> {
    for (let attempt = 1; attempt <= GmailClient.maxAttempts; attempt += 1) {
      let response: Response;
      try {
        response = await fetch(`https://gmail.googleapis.com/gmail/v1${path}`, {
          ...init,
          headers: {
            Authorization: `Bearer ${accessToken}`,
            ...init.headers,
          },
          signal: AbortSignal.timeout(20_000),
        });
      } catch {
        if (attempt === GmailClient.maxAttempts) {
          throw new BadGatewayException("Could not reach the Gmail API.");
        }
        await this.waitBeforeRetry(attempt);
        continue;
      }

      if (response.ok) {
        const body = await response.text();
        return body.trim() ? (JSON.parse(body) as T) : (undefined as T);
      }

      const reason = parseErrorReason(await response.text());
      const retryAfterMs = gmailRetryAfterMs(
        response.headers.get("retry-after"),
      );
      if (
        this.isRetryableStatus(response.status, reason) &&
        attempt < GmailClient.maxAttempts &&
        retryAfterMs < 60_000
      ) {
        await this.waitBeforeRetry(
          attempt,
          response.headers.get("retry-after"),
        );
        continue;
      }

      throw gmailApiError(response.status, reason, retryAfterMs);
    }

    throw new BadGatewayException("Gmail API request failed.");
  }

  private metadataQuery() {
    const params = new URLSearchParams({
      format: "metadata",
      metadataHeaders: "From",
    });
    for (const header of [
      "Subject",
      "Date",
      "Sender",
      "Reply-To",
      "Return-Path",
      "Authentication-Results",
      "ARC-Authentication-Results",
      "DKIM-Signature",
      "List-Id",
      "List-Unsubscribe",
      "List-Unsubscribe-Post",
    ]) {
      params.append("metadataHeaders", header);
    }
    return params.toString();
  }

  private waitBeforeRetry(attempt: number, retryAfter?: string | null) {
    const retrySeconds = retryAfter ? Number(retryAfter) : Number.NaN;
    const exponentialDelay = Math.min(500 * 2 ** (attempt - 1), 30_000);
    const jitter = Math.floor(Math.random() * Math.min(500, exponentialDelay));
    const delay = Number.isFinite(retrySeconds)
      ? Math.min(retrySeconds * 1_000, 60_000)
      : exponentialDelay + jitter;
    return new Promise((resolve) => setTimeout(resolve, delay));
  }

  private isRetryableStatus(status: number, reason?: string) {
    return (
      status === 429 ||
      status >= 500 ||
      (status === 403 &&
        (reason === "rateLimitExceeded" || reason === "userRateLimitExceeded"))
    );
  }
}
