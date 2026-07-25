import { GmailClient } from "./gmail.client";

function batchResponse(
  boundary: string,
  items: Array<{ status: number; body?: object }>,
) {
  const payload = items
    .map(({ status, body }) =>
      [
        `--${boundary}`,
        "Content-Type: application/http",
        "",
        `HTTP/1.1 ${status} Result`,
        "Content-Type: application/json",
        "",
        body ? JSON.stringify(body) : "{}",
        "",
      ].join("\r\n"),
    )
    .concat(`--${boundary}--`)
    .join("\r\n");
  return new Response(payload, {
    status: 200,
    headers: { "content-type": `multipart/mixed; boundary=${boundary}` },
  });
}

describe("GmailClient metadata batches", () => {
  afterEach(() => jest.restoreAllMocks());

  it("retries only rate-limited batch items and preserves result order", async () => {
    const client = new GmailClient();
    jest
      .spyOn(client as never, "waitBeforeRetry")
      .mockResolvedValue(undefined as never);
    const fetchMock = jest
      .spyOn(global, "fetch")
      .mockResolvedValueOnce(
        batchResponse("first", [
          {
            status: 200,
            body: { id: "message-1", threadId: "thread-1" },
          },
          { status: 429 },
        ]),
      )
      .mockResolvedValueOnce(
        batchResponse("second", [
          {
            status: 200,
            body: { id: "message-2", threadId: "thread-2" },
          },
        ]),
      );

    const result = await client.getMessagesBatch("token", [
      "message-1",
      "message-2",
    ]);

    expect(result.map(({ status }) => status)).toEqual([200, 200]);
    expect(result.map(({ message }) => message?.id)).toEqual([
      "message-1",
      "message-2",
    ]);
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(String(fetchMock.mock.calls[1][1]?.body)).toContain("message-2");
    expect(String(fetchMock.mock.calls[1][1]?.body)).not.toContain("message-1");
  });

  it("retries a rate-limited whole batch", async () => {
    const client = new GmailClient();
    jest
      .spyOn(client as never, "waitBeforeRetry")
      .mockResolvedValue(undefined as never);
    jest
      .spyOn(global, "fetch")
      .mockResolvedValueOnce(new Response("", { status: 429 }))
      .mockResolvedValueOnce(
        batchResponse("retry", [
          {
            status: 200,
            body: { id: "message-1", threadId: "thread-1" },
          },
        ]),
      );

    const result = await client.getMessagesBatch("token", ["message-1"]);

    expect(result[0]).toMatchObject({
      status: 200,
      message: { id: "message-1" },
    });
  });
});
