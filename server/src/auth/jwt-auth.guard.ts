import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { Reflector } from "@nestjs/core";
import { Request } from "express";
import { AccessTokenPayload, AuthUser } from "./auth-user.interface";
import { IS_PUBLIC_KEY } from "./public.decorator";
import { RECENT_AUTH_MAX_AGE_SECONDS_KEY } from "./require-recent-auth.decorator";
import { PrismaService } from "../database/prisma.service";

type AuthenticatedRequest = Request & { user?: AuthUser };

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const authorization = request.headers.authorization;
    const [scheme, token] = authorization?.split(" ") ?? [];
    if (scheme?.toLowerCase() !== "bearer" || !token) {
      throw new UnauthorizedException("A valid app session is required.");
    }

    let payload: AccessTokenPayload;
    try {
      payload = await this.jwt.verifyAsync<AccessTokenPayload>(token);
    } catch {
      throw new UnauthorizedException("The app session is invalid or expired.");
    }
    if (
      payload.type !== "access" ||
      !payload.sub ||
      !payload.email ||
      !payload.sid ||
      !payload.auth_time
    ) {
      throw new UnauthorizedException("The app session is invalid or expired.");
    }
    if (!this.prisma.mockDataEnabled) {
      const session = await this.prisma.appSession.findFirst({
        where: {
          id: payload.sid,
          userId: payload.sub,
          revokedAt: null,
          expiresAt: { gt: new Date() },
          user: { deletedAt: null },
        },
        select: { id: true },
      });
      if (!session) {
        throw new UnauthorizedException("The app session has been revoked.");
      }
    }
    request.user = {
      id: payload.sub,
      email: payload.email,
      sessionId: payload.sid,
      authenticatedAt: payload.auth_time,
    };
    const recentAuthMaxAge = this.reflector.getAllAndOverride<number>(
      RECENT_AUTH_MAX_AGE_SECONDS_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (
      recentAuthMaxAge != null &&
      Math.floor(Date.now() / 1_000) - payload.auth_time > recentAuthMaxAge
    ) {
      throw new UnauthorizedException(
        "Recent authentication is required for this action.",
      );
    }
    return true;
  }
}
