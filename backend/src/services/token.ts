import { createHmac, timingSafeEqual } from "node:crypto";

// A standard HS256 JWT built with Node's crypto, so no extra package. It names
// the owner and their store, because storeId is never taken from a request body
// (contract wire rule 4).

export type TokenClaims = { userId: string; storeId: string };

// The owner signs in once on their phone (F2), so the token lasts a long time.
const TOKEN_LIFETIME_SECONDS = 90 * 24 * 60 * 60;
const HEADER = toBase64Url(JSON.stringify({ alg: "HS256", typ: "JWT" }));

export function signToken(claims: TokenClaims, options: { secret: string; nowSeconds: number }): string {
  const payload = toBase64Url(
    JSON.stringify({ sub: claims.userId, store: claims.storeId, iat: options.nowSeconds, exp: options.nowSeconds + TOKEN_LIFETIME_SECONDS }),
  );
  return `${HEADER}.${payload}.${sign(`${HEADER}.${payload}`, options.secret)}`;
}

// Null for anything not signed by us, not HS256, malformed or expired.
export function readToken(token: string, options: { secret: string; nowSeconds: number }): TokenClaims | null {
  const [header, payload, signature] = token.split(".");
  if (header !== HEADER || payload === undefined || signature === undefined) {
    return null;
  }
  const expected = Buffer.from(sign(`${header}.${payload}`, options.secret));
  const actual = Buffer.from(signature);
  if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
    return null;
  }
  const claims = parsePayload(payload);
  if (claims === null || claims.exp <= options.nowSeconds) {
    return null;
  }
  return { userId: claims.sub, storeId: claims.store };
}

function parsePayload(payload: string): { sub: string; store: string; exp: number } | null {
  try {
    const value = JSON.parse(Buffer.from(payload, "base64url").toString("utf8")) as Record<string, unknown>;
    const isValid = typeof value.sub === "string" && typeof value.store === "string" && typeof value.exp === "number";
    return isValid ? { sub: value.sub as string, store: value.store as string, exp: value.exp as number } : null;
  } catch {
    // A payload that is not JSON is a forged or broken token: the caller answers 401.
    return null;
  }
}

function sign(data: string, secret: string): string {
  return createHmac("sha256", secret).update(data).digest("base64url");
}

function toBase64Url(text: string): string {
  return Buffer.from(text).toString("base64url");
}
