import { test } from "node:test";
import assert from "node:assert/strict";
import { readToken, signToken } from "../../src/services/token.js";

const secret = "test-secret";
const nowSeconds = 1_800_000_000;
const claims = { userId: "user-1", storeId: "store-1" };

test("readsBackTheOwnerAndStoreItSigned", () => {
  const token = signToken(claims, { secret, nowSeconds });
  assert.deepEqual(readToken(token, { secret, nowSeconds: nowSeconds + 60 }), claims);
});

test("rejectsATokenWithAChangedPayloadOrAnotherSecret", () => {
  const token = signToken(claims, { secret, nowSeconds });
  const [header, , signature] = token.split(".");
  const otherStore = Buffer.from(JSON.stringify({ sub: "user-1", store: "store-2", iat: nowSeconds, exp: nowSeconds + 999 })).toString("base64url");
  assert.equal(readToken(`${header}.${otherStore}.${signature}`, { secret, nowSeconds }), null);
  assert.equal(readToken(token, { secret: "another-secret", nowSeconds }), null);
});

test("rejectsAnExpiredTokenAfterNinetyDays", () => {
  const token = signToken(claims, { secret, nowSeconds });
  assert.notEqual(readToken(token, { secret, nowSeconds: nowSeconds + 89 * 86_400 }), null);
  assert.equal(readToken(token, { secret, nowSeconds: nowSeconds + 90 * 86_400 }), null);
});

test("rejectsGarbageAndUnsignedTokens", () => {
  const unsignedHeader = Buffer.from(JSON.stringify({ alg: "none", typ: "JWT" })).toString("base64url");
  const payload = Buffer.from(JSON.stringify({ sub: "user-1", store: "store-1", exp: nowSeconds + 999 })).toString("base64url");
  for (const token of ["", "abc", "a.b.c", `${unsignedHeader}.${payload}.`]) {
    assert.equal(readToken(token, { secret, nowSeconds }), null, token);
  }
});
