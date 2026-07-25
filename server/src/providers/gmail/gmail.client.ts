import { BadGatewayException, Injectable } from "@nestjs/common";

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
}

export class GmailApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = "GmailApiError";
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
        if (this.isRetryableStatus(result.status)) {
          retryIds.push(result.id);
        } else {
          results.set(result.id, result);
        }
      }
      pendingIds = retryIds;
      if (pendingIds.length > 0 && attempt < GmailClient.maxAttempts) {
        await this.waitBeforeRetry(attempt);
      }
    }
    for (const id of pendingIds) {
      results.set(id, { id, status: 429 });
    }
    return messageIds.map((id) => results.get(id) ?? { id, status: 502 });
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
    if (this.isRetryableStatus(response.status)) {
      return messageIds.map((id) => ({ id, status: response.status }));
    }
    if (!response.ok) {
      throw new GmailApiError(
        response.status,
        `Gmail batch request failed with status ${response.status}.`,
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
        return { id: messageIds[index], status };
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

      if (
        this.isRetryableStatus(response.status) &&
        attempt < GmailClient.maxAttempts
      ) {
        await this.waitBeforeRetry(
          attempt,
          response.headers.get("retry-after"),
        );
        continue;
      }

      throw new GmailApiError(
        response.status,
        `Gmail API request failed with status ${response.status}.`,
      );
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

  private isRetryableStatus(status: number) {
    return status === 429 || status >= 500;
  }
}
