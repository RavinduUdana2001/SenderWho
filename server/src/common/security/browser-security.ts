import { randomBytes } from "node:crypto";
import type { NextFunction, Request, Response } from "express";
import helmet from "helmet";

// One unpredictable nonce per response, shared by the header and OAuth template.
export function browserSecurity() {
  const headers = helmet({
    contentSecurityPolicy: {
      useDefaults: false,
      directives: {
        defaultSrc: ["'none'"],
        scriptSrc: [
          (_request, response) =>
            `'nonce-${(response as Response).locals.cspNonce}'`,
        ],
        scriptSrcAttr: ["'none'"],
        styleSrc: ["'unsafe-inline'"],
        objectSrc: ["'none'"],
        baseUri: ["'none'"],
        frameAncestors: ["'none'"],
        formAction: ["'none'"],
      },
    },
    crossOriginResourcePolicy: { policy: "same-site" },
    referrerPolicy: { policy: "no-referrer" },
  });
  return (request: Request, response: Response, next: NextFunction) => {
    response.locals.cspNonce = randomBytes(18).toString("base64");
    headers(request, response, next);
  };
}
