import { test } from "node:test";
import assert from "node:assert/strict";
import { hashPassword, isPasswordCorrect } from "../../src/services/password.js";

test("acceptsTheRightPasswordAndRejectsAWrongOne", async () => {
  const stored = await hashPassword("warung123");
  assert.equal(await isPasswordCorrect("warung123", stored), true);
  assert.equal(await isPasswordCorrect("warung124", stored), false);
});

test("saltsEachHashSoTheSamePasswordStoresDifferently", async () => {
  const [first, second] = await Promise.all([hashPassword("warung123"), hashPassword("warung123")]);
  assert.notEqual(first, second);
  assert.doesNotMatch(first, /warung123/);
});

test("rejectsAStoredValueThatIsNotAScryptHash", async () => {
  assert.equal(await isPasswordCorrect("warung123", "warung123"), false);
});
