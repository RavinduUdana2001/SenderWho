import {
  checkEncodedParameters,
  verifyJsonParameters,
} from "./request-parameters";
describe("request ambiguity rejection", () => {
  it.each(["state=a&state=b", "code=a&%63ode=a", "id=1&id[]=2"])(
    "rejects query/form duplicates: %s",
    (input) => {
      expect(() => checkEncodedParameters(input)).toThrow(
        "Duplicate request parameters",
      );
    },
  );
  it.each(['{"id":1,"id":2}', '{"x":{"role":1,"ro\\u006ce":2}}'])(
    "rejects duplicate JSON keys: %s",
    (input) => {
      expect(() =>
        verifyJsonParameters(null, null, Buffer.from(input)),
      ).toThrow("Duplicate request parameters");
    },
  );
  it("allows arrays, nested independent keys and escaped string values", () => {
    expect(() =>
      verifyJsonParameters(
        null,
        null,
        Buffer.from(
          JSON.stringify({
            ids: ["one", "two"],
            a: { id: 1 },
            b: { id: 2 },
            text: 'a"b\\c',
          }),
        ),
      ),
    ).not.toThrow();
  });
  it("rejects malformed JSON with a safe message", () => {
    expect(() =>
      verifyJsonParameters(null, null, Buffer.from('{"secret":bad}')),
    ).toThrow("Invalid JSON request.");
  });
});
