export interface AuthUser {
  id: string;
  email: string;
  sessionId: string;
  authenticatedAt: number;
}

export interface AccessTokenPayload {
  sub: string;
  email: string;
  type: "access";
  sid: string;
  auth_time: number;
  iat?: number;
  exp?: number;
}
