import { BadGatewayException } from "@nestjs/common";
import { MicrosoftGraphClient } from "./microsoft-graph.client";

describe("MicrosoftGraphClient", () => {
  afterEach(() => jest.restoreAllMocks());

  it("maps Graph delta messages into the shared mailbox metadata model", async () => {
    const client = new MicrosoftGraphClient();
    const fetchMock = jest.spyOn(global, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          value: [
            {
              id: "immutable-message-1",
              conversationId: "conversation-1",
              subject: "Monthly update",
              bodyPreview: "A short preview",
              receivedDateTime: "2026-09-07T12:00:00Z",
              from: {
                emailAddress: {
                  name: "Example Sender",
                  address: "news@example.com",
                },
              },
              internetMessageHeaders: [
                {
                  name: "List-Unsubscribe",
                  value: "<https://example.com/unsubscribe>",
                },
              ],
              isRead: false,
              hasAttachments: true,
              parentFolderId: "inbox-id",
              importance: "high",
            },
          ],
          "@odata.deltaLink":
            "https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messages/delta?$deltatoken=safe",
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      ),
    );

    const result = await client.listMessageDelta("access-token", "inbox-id", {
      "inbox-id": "inbox",
    });

    expect(result.messages).toHaveLength(1);
    expect(result.messages[0]).toMatchObject({
      id: "immutable-message-1",
      threadId: "conversation-1",
      labelIds: expect.arrayContaining(["INBOX", "UNREAD", "IMPORTANT"]),
      snippet: "A short preview",
    });
    expect(result.messages[0].payload?.headers).toEqual(
      expect.arrayContaining([
        {
          name: "list-unsubscribe",
          value: "<https://example.com/unsubscribe>",
        },
        { name: "from", value: "Example Sender <news@example.com>" },
      ]),
    );
    expect(fetchMock.mock.calls[0][1]?.headers).toEqual(
      expect.objectContaining({ Prefer: 'IdType="ImmutableId"' }),
    );
  });

  it("uses Graph mailbox actions without requesting send permission", async () => {
    const client = new MicrosoftGraphClient();
    const fetchMock = jest.spyOn(global, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ id: "immutable-message-1" }), {
        status: 200,
        headers: { "content-type": "application/json" },
      }),
    );

    await client.applyMessageAction(
      "access-token",
      "immutable-message-1",
      "trash",
    );

    expect(fetchMock).toHaveBeenCalledWith(
      "https://graph.microsoft.com/v1.0/me/messages/immutable-message-1/move",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({ destinationId: "deleteditems" }),
      }),
    );
  });

  it("rejects an unsafe provider continuation URL", async () => {
    const client = new MicrosoftGraphClient();
    const fetchMock = jest.spyOn(global, "fetch");

    await expect(
      client.listMessageDelta(
        "access-token",
        "inbox-id",
        {},
        "https://attacker.example/steal-token",
      ),
    ).rejects.toBeInstanceOf(BadGatewayException);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
