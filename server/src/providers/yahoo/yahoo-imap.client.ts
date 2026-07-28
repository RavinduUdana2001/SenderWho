import {
  BadGatewayException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { FetchMessageObject, ImapFlow, MessageStructureObject } from "imapflow";
import { simpleParser } from "mailparser";
import { GmailMessage } from "../gmail/gmail.client";

export interface YahooMessagePage {
  messages: GmailMessage[];
  discovered: number;
  nextCursor?: number;
  highestUid?: number;
}

export type YahooMessageAction =
  "archive" | "unarchive" | "trash" | "restore" | "mark_read" | "mark_unread";

export interface YahooMessageContent {
  from: string;
  to: string;
  cc: string;
  subject: string;
  date: string;
  bodyText: string;
  truncated: boolean;
  attachments: Array<{ filename: string; sizeBytes: number }>;
}

@Injectable()
export class YahooImapClient {
  constructor(private readonly config: ConfigService) {}

  async verifyOAuth(email: string, accessToken: string) {
    const client = this.createClient(email, accessToken, true);
    try {
      await client.connect();
    } catch (error) {
      throw this.connectionError(error);
    } finally {
      await this.safeLogout(client);
    }
  }

  async fetchInboxPage(
    email: string,
    accessToken: string,
    beforeUid: number | undefined,
    limit: number,
  ): Promise<YahooMessagePage> {
    const client = this.createClient(email, accessToken);
    try {
      await client.connect();
      const mailbox = await client.mailboxOpen("INBOX", { readOnly: true });
      const allUids = (await client.search({ all: true }, { uid: true })) || [];
      allUids.sort((left, right) => left - right);
      const eligible = beforeUid
        ? allUids.filter((uid) => uid < beforeUid)
        : allUids;
      const start = Math.max(0, eligible.length - limit);
      const selected = eligible.slice(start);
      const fetched =
        selected.length === 0
          ? []
          : await client.fetchAll(
              selected,
              {
                uid: true,
                flags: true,
                envelope: true,
                internalDate: true,
                size: true,
                bodyStructure: true,
                headers: [
                  "from",
                  "sender",
                  "reply-to",
                  "return-path",
                  "subject",
                  "date",
                  "authentication-results",
                  "arc-authentication-results",
                  "dkim-signature",
                  "list-id",
                  "list-unsubscribe",
                  "list-unsubscribe-post",
                ],
              },
              { uid: true },
            );
      const messages = fetched
        .sort((left, right) => right.uid - left.uid)
        .map((message) => this.toProviderMessage(message));
      const nextCursor = start > 0 ? selected[0] : undefined;
      return {
        messages,
        discovered: selected.length,
        nextCursor,
        highestUid: Math.max(0, mailbox.uidNext - 1),
      };
    } catch (error) {
      throw this.connectionError(error);
    } finally {
      await this.safeLogout(client);
    }
  }

  async applyMessageAction(
    email: string,
    accessToken: string,
    providerMessageId: string,
    action: YahooMessageAction,
  ) {
    const parsed = /^yahoo-(inbox|archive|trash)-(\d+)$/.exec(
      providerMessageId,
    );
    if (!parsed) throw new Error("Yahoo message identifier is invalid.");
    const sourceKind = parsed[1];
    const uid = Number(parsed[2]);
    const client = this.createClient(email, accessToken);
    try {
      await client.connect();
      const mailboxes = await client.list();
      const paths = {
        inbox: "INBOX",
        archive:
          mailboxes.find((mailbox) => mailbox.specialUse === "\\Archive")
            ?.path ?? "Archive",
        trash:
          mailboxes.find((mailbox) => mailbox.specialUse === "\\Trash")?.path ??
          "Trash",
      };
      const sourcePath = paths[sourceKind as keyof typeof paths];
      await client.mailboxOpen(sourcePath, { readOnly: false });
      if (action === "mark_read" || action === "mark_unread") {
        const changed =
          action === "mark_read"
            ? await client.messageFlagsAdd(uid, ["\\Seen"], { uid: true })
            : await client.messageFlagsRemove(uid, ["\\Seen"], { uid: true });
        if (!changed) throw new Error("Yahoo message flags were not updated.");
        return { providerMessageId };
      }
      const targetKind =
        action === "trash"
          ? "trash"
          : action === "archive"
            ? "archive"
            : "inbox";
      const targetPath = paths[targetKind];
      const moved = await client.messageMove(uid, targetPath, { uid: true });
      if (!moved) throw new Error("Yahoo message was not moved.");
      const nextUid = moved.uidMap?.get(uid);
      return {
        providerMessageId: nextUid
          ? `yahoo-${targetKind}-${nextUid}`
          : providerMessageId,
      };
    } catch (error) {
      throw this.connectionError(error);
    } finally {
      await this.safeLogout(client);
    }
  }

  async getMessageContent(
    email: string,
    accessToken: string,
    providerMessageId: string,
  ): Promise<YahooMessageContent> {
    const parsedId = /^yahoo-(inbox|archive|trash)-(\d+)$/.exec(
      providerMessageId,
    );
    if (!parsedId) throw new Error("Yahoo message identifier is invalid.");
    const client = this.createClient(email, accessToken);
    try {
      await client.connect();
      const mailboxes = await client.list();
      const folder = parsedId[1];
      const sourcePath =
        folder === "inbox"
          ? "INBOX"
          : folder === "archive"
            ? (mailboxes.find((mailbox) => mailbox.specialUse === "\\Archive")
                ?.path ?? "Archive")
            : (mailboxes.find((mailbox) => mailbox.specialUse === "\\Trash")
                ?.path ?? "Trash");
      await client.mailboxOpen(sourcePath, { readOnly: true });
      const message = await client.fetchOne(
        Number(parsedId[2]),
        { source: { maxLength: 10 * 1024 * 1024 } },
        { uid: true },
      );
      if (!message || !message.source) {
        throw new Error("Yahoo message content was not found.");
      }
      const parsed = await simpleParser(message.source, {
        skipImageLinks: true,
        skipHtmlToText: false,
        maxHtmlLengthToParse: 5 * 1024 * 1024,
      });
      const body = (parsed.text ?? "").trim();
      const maxLength = 500_000;
      return {
        from: parsed.from?.text ?? "",
        to: addressText(parsed.to),
        cc: addressText(parsed.cc),
        subject: parsed.subject ?? "(No subject)",
        date: parsed.date?.toISOString() ?? "",
        bodyText: body.slice(0, maxLength),
        truncated: body.length > maxLength,
        attachments: parsed.attachments.map((attachment) => ({
          filename: attachment.filename ?? "Attachment",
          sizeBytes: attachment.size,
        })),
      };
    } catch (error) {
      throw this.connectionError(error);
    } finally {
      await this.safeLogout(client);
    }
  }

  private createClient(email: string, accessToken: string, verifyOnly = false) {
    return new ImapFlow({
      host: this.config.get<string>("oauth.yahoo.imapHost")!,
      port: this.config.get<number>("oauth.yahoo.imapPort", 993),
      secure: true,
      auth: { user: email, accessToken },
      verifyOnly,
      logger: false,
      disableAutoIdle: true,
      connectionTimeout: 15_000,
      greetingTimeout: 15_000,
      socketTimeout: 30_000,
      maxLineLength: 1024 * 1024,
      maxLiteralSize: 10 * 1024 * 1024,
      tls: { minVersion: "TLSv1.2", rejectUnauthorized: true },
      clientInfo: { name: "SenderWho", version: "1.0" },
    });
  }

  private toProviderMessage(message: FetchMessageObject): GmailMessage {
    const headers = parseHeaders(message.headers);
    const from = message.envelope?.from?.[0];
    if (!headers.has("from") && from?.address) {
      headers.set(
        "from",
        from.name ? `${from.name} <${from.address}>` : from.address,
      );
    }
    if (!headers.has("subject") && message.envelope?.subject) {
      headers.set("subject", message.envelope.subject);
    }
    const flags = message.flags ?? new Set<string>();
    const labels = [
      "INBOX",
      ...(!flags.has("\\Seen") ? ["UNREAD"] : []),
      ...(flags.has("\\Flagged") ? ["STARRED"] : []),
    ];
    const date =
      message.internalDate instanceof Date
        ? message.internalDate
        : new Date(
            message.internalDate ?? message.envelope?.date ?? Date.now(),
          );
    return {
      id: `yahoo-inbox-${message.uid}`,
      threadId:
        message.envelope?.messageId?.slice(0, 255) ??
        `yahoo-inbox-${message.uid}`,
      labelIds: labels,
      internalDate: String(date.getTime()),
      sizeEstimate: message.size,
      payload: {
        headers: [...headers].map(([name, value]) => ({ name, value })),
        parts: structureParts(message.bodyStructure),
      },
    };
  }

  private connectionError(error: unknown) {
    const code =
      error && typeof error === "object" && "authenticationFailed" in error
        ? (error as { authenticationFailed?: boolean }).authenticationFailed
        : false;
    const message = error instanceof Error ? error.message.toLowerCase() : "";
    if (
      code ||
      message.includes("authentication") ||
      message.includes("credentials") ||
      message.includes("login")
    ) {
      return new UnauthorizedException(
        "Yahoo Mail authorization expired or was revoked. Reconnect Yahoo Mail and try again.",
      );
    }
    return new BadGatewayException(
      "SenderWho could not securely reach Yahoo Mail. Please try again.",
    );
  }

  private async safeLogout(client: ImapFlow) {
    try {
      if (client.usable) await client.logout();
      else client.close();
    } catch {
      client.close();
    }
  }
}

function addressText(
  value: { text: string } | Array<{ text: string }> | undefined,
) {
  if (!value) return "";
  return Array.isArray(value)
    ? value.map((address) => address.text).join(", ")
    : value.text;
}

function parseHeaders(source?: Buffer) {
  const result = new Map<string, string>();
  if (!source) return result;
  const unfolded = source
    .toString("utf8")
    .replace(/\r?\n[ \t]+/g, " ")
    .split(/\r?\n/);
  for (const line of unfolded) {
    const separator = line.indexOf(":");
    if (separator <= 0) continue;
    const name = line.slice(0, separator).trim().toLowerCase();
    const value = line.slice(separator + 1).trim();
    if (name && value && !result.has(name)) result.set(name, value);
  }
  return result;
}

function structureParts(
  structure?: MessageStructureObject,
): GmailMessage["payload"][] | undefined {
  if (!structure) return undefined;
  const children = structure.childNodes?.map(toPayloadPart) ?? [];
  return children.length > 0 ? children : [toPayloadPart(structure)];
}

function toPayloadPart(
  structure: MessageStructureObject,
): NonNullable<GmailMessage["payload"]> {
  return {
    mimeType: structure.type,
    filename:
      structure.dispositionParameters?.filename ??
      structure.parameters?.name ??
      undefined,
    body: { size: structure.size },
    parts: structure.childNodes?.map(toPayloadPart),
  };
}
