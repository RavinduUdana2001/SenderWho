import {
  BadGatewayException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { GmailMessage } from "../gmail/gmail.client";

const GRAPH_ORIGIN = "https://graph.microsoft.com";
const GRAPH_BASE_URL = `${GRAPH_ORIGIN}/v1.0`;
const MAX_ATTEMPTS = 5;
const MAX_CONTENT_LENGTH = 500_000;

export type MicrosoftMessageAction =
  "archive" | "unarchive" | "trash" | "restore" | "mark_read" | "mark_unread";

export class MicrosoftGraphError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = "MicrosoftGraphError";
  }
}

export interface MicrosoftProfile {
  id: string;
  displayName?: string;
  mail?: string;
  userPrincipalName?: string;
}

export interface MicrosoftFolder {
  id: string;
  displayName: string;
  parentFolderId?: string;
  childFolderCount: number;
}

export interface MicrosoftDeltaPage {
  messages: GmailMessage[];
  removedMessageIds: string[];
  nextLink?: string;
  deltaLink?: string;
  discovered: number;
}

interface GraphCollection<T> {
  value?: T[];
  "@odata.nextLink"?: string;
  "@odata.deltaLink"?: string;
}

interface GraphEmailAddress {
  name?: string;
  address?: string;
}

interface GraphRecipient {
  emailAddress?: GraphEmailAddress;
}

interface GraphHeader {
  name?: string;
  value?: string;
}

interface GraphMessage {
  id?: string;
  conversationId?: string;
  subject?: string;
  bodyPreview?: string;
  receivedDateTime?: string;
  from?: GraphRecipient;
  replyTo?: GraphRecipient[];
  toRecipients?: GraphRecipient[];
  ccRecipients?: GraphRecipient[];
  internetMessageHeaders?: GraphHeader[];
  categories?: string[];
  isRead?: boolean;
  flag?: { flagStatus?: string };
  hasAttachments?: boolean;
  parentFolderId?: string;
  importance?: string;
  body?: { contentType?: string; content?: string };
  "@removed"?: { reason?: string };
}

interface GraphAttachment {
  name?: string;
  size?: number;
  isInline?: boolean;
}

@Injectable()
export class MicrosoftGraphClient {
  async getProfile(accessToken: string): Promise<MicrosoftProfile> {
    const params = new URLSearchParams({
      $select: "id,displayName,mail,userPrincipalName",
    });
    return this.request<MicrosoftProfile>(
      `/me?${params.toString()}`,
      accessToken,
    );
  }

  async listMailFolders(accessToken: string): Promise<MicrosoftFolder[]> {
    const folders: MicrosoftFolder[] = [];
    const folderIds = new Set<string>();
    let nextUrl: string | undefined =
      this.folderCollectionUrl("/me/mailFolders");
    while (nextUrl) {
      const page: GraphCollection<MicrosoftFolder> = await this.requestUrl<
        GraphCollection<MicrosoftFolder>
      >(nextUrl, accessToken);
      for (const folder of page.value ?? []) {
        if (folder.id && !folderIds.has(folder.id) && folders.length < 500) {
          folderIds.add(folder.id);
          folders.push(folder);
        }
      }
      nextUrl = page["@odata.nextLink"];
      if (folders.length >= 500) break;
    }

    // Graph returns only root folders from this collection. Walk child folders
    // with a strict bound so a malformed mailbox cannot create an endless scan.
    for (
      let index = 0;
      index < folders.length && folders.length < 500;
      index += 1
    ) {
      const folder = folders[index];
      if (!folder.childFolderCount) continue;
      let childUrl: string | undefined = this.folderCollectionUrl(
        `/me/mailFolders/${encodeURIComponent(folder.id)}/childFolders`,
      );
      while (childUrl) {
        const page: GraphCollection<MicrosoftFolder> = await this.requestUrl<
          GraphCollection<MicrosoftFolder>
        >(childUrl, accessToken);
        for (const child of page.value ?? []) {
          if (child.id && !folderIds.has(child.id) && folders.length < 500) {
            folderIds.add(child.id);
            folders.push(child);
          }
        }
        childUrl = page["@odata.nextLink"];
        if (folders.length >= 500) break;
      }
    }

    const excluded = new Set<string>();
    await Promise.all(
      ["drafts", "sentitems", "outbox"].map(async (wellKnownName) => {
        try {
          const folder = await this.request<{ id?: string }>(
            `/me/mailFolders/${wellKnownName}?$select=id`,
            accessToken,
          );
          if (folder.id) excluded.add(folder.id);
        } catch (error) {
          if (error instanceof UnauthorizedException) throw error;
        }
      }),
    );
    return folders.filter((folder) => !excluded.has(folder.id));
  }

  async getFolderKinds(accessToken: string) {
    const entries = await Promise.all(
      ["inbox", "archive", "deleteditems", "junkemail"].map(
        async (wellKnownName) => {
          try {
            const folder = await this.request<{ id?: string }>(
              `/me/mailFolders/${wellKnownName}?$select=id`,
              accessToken,
            );
            return folder.id ? ([folder.id, wellKnownName] as const) : null;
          } catch (error) {
            if (error instanceof UnauthorizedException) throw error;
            return null;
          }
        },
      ),
    );
    return Object.fromEntries(
      entries.filter((entry) => entry !== null),
    ) as Record<string, string>;
  }

  async listMessageDelta(
    accessToken: string,
    folderId: string,
    folderKinds: Record<string, string>,
    cursorUrl?: string,
  ): Promise<MicrosoftDeltaPage> {
    const select = [
      "id",
      "conversationId",
      "subject",
      "bodyPreview",
      "receivedDateTime",
      "from",
      "replyTo",
      "internetMessageHeaders",
      "categories",
      "isRead",
      "flag",
      "hasAttachments",
      "parentFolderId",
      "importance",
    ].join(",");
    const initialUrl = new URL(
      `${GRAPH_BASE_URL}/me/mailFolders/${encodeURIComponent(folderId)}/messages/delta`,
    );
    initialUrl.searchParams.set("$select", select);
    initialUrl.searchParams.set("$top", "50");
    const page = await this.requestUrl<GraphCollection<GraphMessage>>(
      cursorUrl ?? initialUrl.toString(),
      accessToken,
    );
    const messages: GmailMessage[] = [];
    const removalCandidates: string[] = [];
    for (const message of page.value ?? []) {
      if (!message.id) continue;
      if (message["@removed"]) {
        removalCandidates.push(message.id);
      } else {
        messages.push(this.toProviderMessage(message, folderKinds));
      }
    }
    // Folder delta reports a move as a removal from the source folder. Resolve
    // each candidate by immutable ID before deleting local metadata so a move
    // cannot make a valid message disappear from SenderWho.
    const removedMessageIds: string[] = [];
    for (let index = 0; index < removalCandidates.length; index += 5) {
      const results = await Promise.all(
        removalCandidates.slice(index, index + 5).map(async (messageId) => {
          try {
            const current = await this.request<GraphMessage>(
              `/me/messages/${encodeURIComponent(messageId)}?$select=${select}`,
              accessToken,
            );
            return current.id
              ? this.toProviderMessage(current, folderKinds)
              : null;
          } catch (error) {
            if (error instanceof MicrosoftGraphError && error.status === 404) {
              return null;
            }
            throw error;
          }
        }),
      );
      results.forEach((message, offset) => {
        if (message) {
          messages.push(message);
        } else {
          removedMessageIds.push(removalCandidates[index + offset]);
        }
      });
    }
    return {
      messages,
      removedMessageIds,
      nextLink: page["@odata.nextLink"],
      deltaLink: page["@odata.deltaLink"],
      discovered: (page.value ?? []).length,
    };
  }

  async applyMessageAction(
    accessToken: string,
    providerMessageId: string,
    action: MicrosoftMessageAction,
  ) {
    if (action === "mark_read" || action === "mark_unread") {
      const updated = await this.request<GraphMessage>(
        `/me/messages/${encodeURIComponent(providerMessageId)}`,
        accessToken,
        {
          method: "PATCH",
          body: JSON.stringify({ isRead: action === "mark_read" }),
        },
      );
      return { providerMessageId: updated.id ?? providerMessageId };
    }

    const destinationId =
      action === "trash"
        ? "deleteditems"
        : action === "archive"
          ? "archive"
          : "inbox";
    const moved = await this.request<GraphMessage>(
      `/me/messages/${encodeURIComponent(providerMessageId)}/move`,
      accessToken,
      {
        method: "POST",
        body: JSON.stringify({ destinationId }),
      },
    );
    return { providerMessageId: moved.id ?? providerMessageId };
  }

  async getMessageContent(accessToken: string, providerMessageId: string) {
    const params = new URLSearchParams({
      $select:
        "id,from,toRecipients,ccRecipients,subject,receivedDateTime,body,hasAttachments",
    });
    const message = await this.request<GraphMessage>(
      `/me/messages/${encodeURIComponent(providerMessageId)}?${params.toString()}`,
      accessToken,
      undefined,
      { Prefer: 'IdType="ImmutableId", outlook.body-content-type="text"' },
    );
    let attachments: Array<{ filename: string; sizeBytes: number }> = [];
    if (message.hasAttachments) {
      const attachmentParams = new URLSearchParams({
        $select: "name,size,isInline",
        $top: "100",
      });
      const response = await this.request<GraphCollection<GraphAttachment>>(
        `/me/messages/${encodeURIComponent(providerMessageId)}/attachments?${attachmentParams.toString()}`,
        accessToken,
      );
      attachments = (response.value ?? [])
        .filter((attachment) => attachment.isInline !== true)
        .map((attachment) => ({
          filename: attachment.name?.trim() || "Attachment",
          sizeBytes: Math.max(0, attachment.size ?? 0),
        }));
    }
    const body = this.plainText(message.body?.content ?? "");
    return {
      from: this.recipientText(message.from),
      to: (message.toRecipients ?? [])
        .map((item) => this.recipientText(item))
        .filter(Boolean)
        .join(", "),
      cc: (message.ccRecipients ?? [])
        .map((item) => this.recipientText(item))
        .filter(Boolean)
        .join(", "),
      subject: message.subject?.trim() || "(No subject)",
      date: message.receivedDateTime ?? "",
      bodyText: body.slice(0, MAX_CONTENT_LENGTH),
      truncated: body.length > MAX_CONTENT_LENGTH,
      attachments,
    };
  }

  private folderCollectionUrl(path: string) {
    const url = new URL(`${GRAPH_BASE_URL}${path}`);
    url.searchParams.set(
      "$select",
      "id,displayName,parentFolderId,childFolderCount",
    );
    url.searchParams.set("$top", "100");
    url.searchParams.set("includeHiddenFolders", "true");
    return url.toString();
  }

  private toProviderMessage(
    message: GraphMessage,
    folderKinds: Record<string, string>,
  ): GmailMessage {
    const headers = new Map<string, string>();
    for (const header of message.internetMessageHeaders ?? []) {
      const name = header.name?.trim();
      const value = header.value?.trim();
      if (name && value && !headers.has(name.toLowerCase())) {
        headers.set(name.toLowerCase(), value);
      }
    }
    const from = this.recipientText(message.from);
    if (from && !headers.has("from")) headers.set("from", from);
    const replyTo = (message.replyTo ?? [])
      .map((recipient) => this.recipientText(recipient))
      .filter(Boolean)
      .join(", ");
    if (replyTo && !headers.has("reply-to")) headers.set("reply-to", replyTo);
    if (message.subject && !headers.has("subject")) {
      headers.set("subject", message.subject);
    }
    if (message.receivedDateTime && !headers.has("date")) {
      headers.set("date", message.receivedDateTime);
    }

    const kind = message.parentFolderId
      ? folderKinds[message.parentFolderId]
      : undefined;
    const labelIds = [
      ...(kind === "inbox" ? ["INBOX"] : []),
      ...(kind === "deleteditems" ? ["TRASH"] : []),
      ...(kind === "junkemail" ? ["SPAM"] : []),
      ...(message.isRead === false ? ["UNREAD"] : []),
      ...(message.flag?.flagStatus === "flagged" ? ["STARRED"] : []),
      ...(message.importance === "high" ? ["IMPORTANT"] : []),
      ...(message.categories ?? []).map(
        (category) => `MS_CATEGORY_${category}`,
      ),
    ];
    const receivedAt = new Date(message.receivedDateTime ?? Date.now());
    return {
      id: message.id!,
      threadId: message.conversationId ?? message.id!,
      labelIds,
      snippet: message.bodyPreview?.slice(0, 2_000),
      internalDate: String(
        Number.isNaN(receivedAt.getTime()) ? Date.now() : receivedAt.getTime(),
      ),
      payload: {
        headers: [...headers].map(([name, value]) => ({ name, value })),
        parts: message.hasAttachments
          ? [{ filename: "Attachment", body: { size: 0 } }]
          : [],
      },
    };
  }

  private recipientText(recipient?: GraphRecipient) {
    const address = recipient?.emailAddress?.address?.trim() ?? "";
    const name = recipient?.emailAddress?.name?.trim() ?? "";
    if (!address) return "";
    return name ? `${name} <${address}>` : address;
  }

  private plainText(value: string) {
    return value
      .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, " ")
      .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, " ")
      .replace(/<(br|\/p|\/div|\/li)>/gi, "\n")
      .replace(/<[^>]+>/g, " ")
      .replace(/&nbsp;/gi, " ")
      .replace(/&amp;/gi, "&")
      .replace(/&lt;/gi, "<")
      .replace(/&gt;/gi, ">")
      .replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, "'")
      .replace(/[ \t]+/g, " ")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
  }

  private request<T>(
    path: string,
    accessToken: string,
    init?: RequestInit,
    headers?: Record<string, string>,
  ) {
    return this.requestUrl<T>(
      `${GRAPH_BASE_URL}${path}`,
      accessToken,
      init,
      headers,
    );
  }

  private async requestUrl<T>(
    requestUrl: string,
    accessToken: string,
    init: RequestInit = {},
    extraHeaders: Record<string, string> = {},
  ): Promise<T> {
    const url = this.validGraphUrl(requestUrl);
    let lastStatus = 502;
    for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
      let response: Response;
      try {
        response = await fetch(url, {
          ...init,
          headers: {
            Authorization: `Bearer ${accessToken}`,
            Accept: "application/json",
            "Content-Type": "application/json",
            Prefer: 'IdType="ImmutableId"',
            ...extraHeaders,
            ...(init.headers ?? {}),
          },
          signal: AbortSignal.timeout(20_000),
        });
      } catch {
        if (attempt < MAX_ATTEMPTS) {
          await this.wait(attempt * 300);
          continue;
        }
        throw new BadGatewayException(
          "SenderWho could not securely reach Microsoft Outlook. Please try again.",
        );
      }
      lastStatus = response.status;
      if (response.ok) {
        if (response.status === 204) return {} as T;
        return (await response.json()) as T;
      }
      if (response.status === 401) {
        throw new UnauthorizedException(
          "Microsoft Outlook authorization expired or was revoked. Reconnect Outlook and try again.",
        );
      }
      if (this.retryable(response.status) && attempt < MAX_ATTEMPTS) {
        const retryAfterHeader = response.headers.get("retry-after");
        const retryAfter = retryAfterHeader
          ? Number(retryAfterHeader)
          : Number.NaN;
        await response.body?.cancel();
        await this.wait(
          Number.isFinite(retryAfter)
            ? Math.min(10_000, Math.max(250, retryAfter * 1_000))
            : Math.min(10_000, 400 * 2 ** (attempt - 1)),
        );
        continue;
      }
      const details = await this.errorMessage(response);
      throw new MicrosoftGraphError(response.status, details);
    }
    throw new MicrosoftGraphError(
      lastStatus,
      "Microsoft Outlook is temporarily unavailable.",
    );
  }

  private validGraphUrl(value: string) {
    let url: URL;
    try {
      url = new URL(value);
    } catch {
      throw new BadGatewayException(
        "Microsoft returned an invalid continuation link.",
      );
    }
    if (
      url.origin !== GRAPH_ORIGIN ||
      !url.pathname.startsWith("/v1.0/") ||
      url.username ||
      url.password
    ) {
      throw new BadGatewayException(
        "Microsoft returned an unsafe continuation link.",
      );
    }
    return url.toString();
  }

  private retryable(status: number) {
    return status === 408 || status === 429 || status >= 500;
  }

  private async errorMessage(response: Response) {
    try {
      const body = (await response.json()) as {
        error?: { code?: string; message?: string };
      };
      const code = body.error?.code?.slice(0, 80) ?? "request_failed";
      return `Microsoft Outlook request failed (${code}).`;
    } catch {
      return "Microsoft Outlook could not complete the mailbox request.";
    }
  }

  private wait(milliseconds: number) {
    return new Promise<void>((resolve) => setTimeout(resolve, milliseconds));
  }
}
