import { GmailClient, gmailApiError } from "./gmail.client";

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

  it("retries only 403 quota-limited items and retains successful messages", async () => {
    const client = new GmailClient();
    jest
      .spyOn(client as never, "waitBeforeRetry")
      .mockResolvedValue(undefined as never);
    const fetchMock = jest
      .spyOn(global, "fetch")
      .mockResolvedValueOnce(
        batchResponse("quota", [
          { status: 200, body: { id: "one", threadId: "thread-one" } },
          {
            status: 403,
            body: { error: { errors: [{ reason: "userRateLimitExceeded" }] } },
          },
        ]),
      )
      .mockResolvedValueOnce(
        batchResponse("ok", [
          { status: 200, body: { id: "two", threadId: "thread-two" } },
        ]),
      );
    const result = await client.getMessagesBatch("token", ["one", "two"]);
    expect(result.map((item) => item.message?.id)).toEqual(["one", "two"]);
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(String(fetchMock.mock.calls[1][1]?.body)).not.toContain(
      "messages/one?",
    );
  });

  it("retains the permission reason from a 403 without retrying it as quota", async () => {
    const client = new GmailClient();
    const fetchMock = jest.spyOn(global, "fetch").mockResolvedValueOnce(
      batchResponse("permission", [
        {
          status: 403,
          body: {
            error: {
              message: "private-account@example.test",
              errors: [{ reason: "insufficientPermissions" }],
            },
          },
        },
      ]),
    );
    const [result] = await client.getMessagesBatch("token", ["one"]);
    expect(result).toMatchObject({
      status: 403,
      errorReason: "insufficientPermissions",
    });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const error = gmailApiError(result.status, result.errorReason);
    expect(error.message).toContain("Reconnect");
    expect(error.message).not.toContain("private-account");
  });

  it("surfaces an expired batch token so the sync caller can refresh it", async () => {
    jest
      .spyOn(global, "fetch")
      .mockResolvedValueOnce(batchResponse("expired", [{ status: 401 }]));
    await expect(
      new GmailClient().getMessagesBatch("expired", ["one"]),
    ).rejects.toMatchObject({ status: 401 });
  });

  it("keeps the final quota reason after bounded retries", async () => {
    const client = new GmailClient();
    jest
      .spyOn(client as never, "waitBeforeRetry")
      .mockResolvedValue(undefined as never);
    const fetchMock = jest.spyOn(global, "fetch").mockImplementation(async () =>
      batchResponse("busy", [
        {
          status: 403,
          body: { error: { errors: [{ reason: "rateLimitExceeded" }] } },
        },
      ]),
    );
    const [result] = await client.getMessagesBatch("token", ["one"]);
    expect(result).toMatchObject({
      status: 403,
      errorReason: "rateLimitExceeded",
    });
    expect(fetchMock).toHaveBeenCalledTimes(5);
    expect(gmailApiError(result.status, result.errorReason).message).toContain(
      "Gmail is busy",
    );
  });

  it("classifies single-message permission failures without exposing raw diagnostics", async () => {
    jest.spyOn(global, "fetch").mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          error: {
            message: "private-account@example.test",
            details: [{ reason: "ACCESS_TOKEN_SCOPE_INSUFFICIENT" }],
          },
        }),
        { status: 403 },
      ),
    );
    await expect(
      new GmailClient().getMessage("token", "one"),
    ).rejects.toMatchObject({
      status: 403,
      reason: "ACCESS_TOKEN_SCOPE_INSUFFICIENT",
      message: expect.stringContaining("Reconnect"),
    });
  });

  it("preserves a long Retry-After for the durable worker without hammering Gmail", async () => {
    const fetchMock = jest.spyOn(global, "fetch").mockResolvedValueOnce(
      new Response("{}", {
        status: 429,
        headers: { "Retry-After": "180" },
      }),
    );
    const [result] = await new GmailClient().getMessagesBatch("token", ["one"]);
    expect(result).toMatchObject({ status: 429, retryAfterMs: 180_000 });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(
      gmailApiError(result.status, result.errorReason, result.retryAfterMs)
        .retryAfterMs,
    ).toBe(180_000);
  });
});
