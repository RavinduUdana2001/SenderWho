/** Google may return canonical UserInfo URLs for short OpenID scope names. */
export function missingGoogleScopes(granted: string[], required: string[]) {
  const scopes = new Set(granted);
  if (scopes.has("https://www.googleapis.com/auth/userinfo.profile")) {
    scopes.add("profile");
  }
  if (scopes.has("email")) {
    scopes.add("https://www.googleapis.com/auth/userinfo.email");
  }
  return required.filter((scope) => !scopes.has(scope));
}
