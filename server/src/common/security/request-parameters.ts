import { BadRequestException } from "@nestjs/common";
import type { NextFunction, Request, Response } from "express";

const failure = () =>
  new BadRequestException("Duplicate request parameters are not allowed.");
export function checkEncodedParameters(value: string): void {
  const seen = new Set<string>();
  for (const key of new URLSearchParams(value).keys()) {
    // Bracket aliases can otherwise be interpreted differently by intermediaries.
    const canonical = key.replace(/\[.*$/, "");
    if (seen.has(canonical)) throw failure();
    seen.add(canonical);
  }
}
export function rejectDuplicateParameters(
  request: Request,
  _response: Response,
  next: NextFunction,
): void {
  try {
    checkEncodedParameters(request.originalUrl.split("?").slice(1).join("?"));
    next();
  } catch (error) {
    next(error);
  }
}
export function verifyFormParameters(
  _request: unknown,
  _response: unknown,
  buffer: Buffer,
): void {
  checkEncodedParameters(buffer.toString("utf8"));
}
export function verifyJsonParameters(
  _request: unknown,
  _response: unknown,
  buffer: Buffer,
): void {
  // body-parser treats an empty JSON body as {}; OAuth start permits no body.
  if (buffer.length === 0) return;
  const source = buffer.toString("utf8");
  // Validate syntax first; never include parser diagnostics or raw input in errors.
  try {
    JSON.parse(source);
  } catch {
    throw new BadRequestException("Invalid JSON request.");
  }
  let offset = 0;
  const whitespace = () => {
    while (/\s/.test(source[offset] ?? "") && offset < source.length) offset++;
  };
  const string = (): string => {
    const start = offset++;
    while (offset < source.length) {
      if (source[offset] === "\\") {
        offset += 2;
        continue;
      }
      if (source[offset++] === '"') break;
    }
    return JSON.parse(source.slice(start, offset)) as string;
  };
  const value = (depth: number): void => {
    if (depth > 100)
      throw new BadRequestException("Request nesting is too deep.");
    whitespace();
    const kind = source[offset];
    if (kind === '"') {
      string();
      return;
    }
    if (kind === "{") {
      offset++;
      whitespace();
      const keys = new Set<string>();
      if (source[offset] === "}") {
        offset++;
        return;
      }
      while (offset < source.length) {
        whitespace();
        const key = string();
        if (keys.has(key)) throw failure();
        keys.add(key);
        whitespace();
        offset++;
        value(depth + 1);
        whitespace();
        if (source[offset++] === "}") return;
      }
    } else if (kind === "[") {
      offset++;
      whitespace();
      if (source[offset] === "]") {
        offset++;
        return;
      }
      while (offset < source.length) {
        value(depth + 1);
        whitespace();
        if (source[offset++] === "]") return;
      }
    } else {
      while (offset < source.length && !/[\s,}\]]/.test(source[offset]))
        offset++;
    }
  };
  value(0);
}
