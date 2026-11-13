import { INestApplication } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Test } from "@nestjs/testing";
import { request } from "node:http";
import { AddressInfo } from "node:net";
import { Parser } from "htmlparser2";
import { AuthController } from "../auth/auth.controller";
import { AuthService } from "../auth/auth.service";
import { browserSecurity } from "../common/security/browser-security";
import { PublicSiteController } from "./public-site.controller";
const attack =
  '"><img src=x onerror=alert(1)></script><script>alert(1)</script>';
describe("XSS controls through actual NestJS controller responses", () => {
  let app: INestApplication;
  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [AuthController, PublicSiteController],
      providers: [
        {
          provide: ConfigService,
          useValue: new ConfigService({
            publicSite: {
              legalName: attack,
              supportEmail: attack,
              effectiveDate: attack,
            },
          }),
        },
        {
          provide: AuthService,
          useValue: {
            failOAuthSession: jest.fn(),
            handleOAuthCallback: jest
              .fn()
              .mockResolvedValue({ emailAddress: attack }),
          },
        },
      ],
    }).compile();
    app = module.createNestApplication({ logger: false });
    app.use(browserSecurity());
    await app.listen(0, "127.0.0.1");
  });
  afterAll(async () => {
    await app?.close();
  });
  const get = (path: string) =>
    new Promise<{ status: number; headers: Record<string, any>; body: string }>(
      (resolve, reject) => {
        const port = (app.getHttpServer().address() as AddressInfo).port;
        request({ host: "127.0.0.1", port, path }, (res) => {
          let body = "";
          res.on("data", (chunk) => (body += chunk));
          res.on("end", () =>
            resolve({ status: res.statusCode!, headers: res.headers, body }),
          );
        })
          .on("error", reject)
          .end();
      },
    );
  function assertSafe(
    response: Awaited<ReturnType<typeof get>>,
    oauth: boolean,
  ) {
    expect(response.status).toBe(200);
    expect(response.headers["content-type"]).toContain("text/html");
    const csp = response.headers["content-security-policy"] as string;
    for (const directive of [
      "default-src 'none'",
      "script-src-attr 'none'",
      "frame-ancestors 'none'",
    ])
      expect(csp).toContain(directive);
    expect(csp).not.toContain("unsafe-eval");
    expect(csp).not.toContain("script-src 'unsafe-inline'");
    let scripts = 0;
    const parser = new Parser({
      onopentag(name, attrs) {
        expect(Object.keys(attrs).filter((k) => /^on/i.test(k))).toEqual([]);
        expect(["img", "svg", "iframe", "object"]).not.toContain(name);
        if (name === "script") {
          scripts++;
          expect(attrs.nonce).toMatch(/^[A-Za-z0-9+/]{24}$/);
          expect(csp).toContain(`script-src 'nonce-${attrs.nonce}'`);
        }
        if (attrs.href)
          expect(attrs.href).toMatch(
            /^(\/|#|https:\/\/senderwho\.com\/|senderwho:\/\/oauth\/callback\?status=(success|failed)$)/,
          );
      },
    });
    parser.write(response.body);
    parser.end();
    expect(scripts).toBe(oauth ? 1 : 0);
    expect(response.body).not.toContain(attack);
    expect(response.headers["x-content-type-options"]).toBe("nosniff");
  }
  it.each(["/", "/privacy", "/terms", "/support", "/delete-account"])(
    "protects public output and header for %s",
    async (path) => assertSafe(await get(path), false),
  );
  it.each(["google", "microsoft", "yahoo"])(
    "protects %s success, denial and missing-code pages",
    async (provider) => {
      for (const query of [
        "?code=synthetic&state=test",
        `?error=${encodeURIComponent(attack)}`,
        "",
      ])
        assertSafe(await get(`/auth/oauth/${provider}/callback${query}`), true);
    },
  );
  it("changes the effective HTTP policy nonce on successive responses", async () => {
    expect(
      (await get("/auth/oauth/google/callback")).headers[
        "content-security-policy"
      ],
    ).not.toBe(
      (await get("/auth/oauth/google/callback")).headers[
        "content-security-policy"
      ],
    );
  });
});
