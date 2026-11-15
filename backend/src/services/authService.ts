import { Prisma, type Store, type User } from "@prisma/client";
import { config } from "../config.js";
import { prisma } from "../db.js";
import { ApiError } from "../errors.js";
import { fixedCategoryRows } from "./categories.js";
import { LoginLimiter } from "./loginLimiter.js";
import { hashPassword, isPasswordCorrect } from "./password.js";
import { normalisePhone } from "./phone.js";
import { toStoreJson, type StoreJson } from "./storeService.js";
import { signToken } from "./token.js";

// Sign-in by phone number and password (#100), in the shapes F2 calls (#173).
// A new owner gets one store straight away, with an empty name, so the app opens
// first-run setup.

export type AccountJson = { user: UserJson; stores: StoreJson[] };
export type SessionJson = AccountJson & { token: string };

type UserJson = { id: string; name: string; phone: string; consentAt: string | null };


const TRIAL_DAYS = 14;
const WRONG_SIGN_IN = "Nomor HP atau kata sandi salah";
// Checked against when the phone number has no account. No password matches it.
const UNKNOWN_USER_HASH = `scrypt$${"0".repeat(32)}$${"0".repeat(128)}`;

const loginLimiter = new LoginLimiter();

export async function register(input: { name: string; phone: string; password: string }): Promise<SessionJson> {
  const phone = requirePhone(input.phone);
  const passwordHash = await hashPassword(input.password);
  const trialEndsAt = new Date(Date.now() + TRIAL_DAYS * 24 * 60 * 60 * 1000);
  try {
    const user = await prisma.user.create({
      data: {
        name: input.name,
        phone,
        passwordHash,
        // Spec §4.2: the fixed categories exist from the start, before the owner
        // picks jenis usaha, since every kind of business uses the same ones.
        stores: { create: { name: "", businessTypes: [], closedDays: [], trialEndsAt, categories: { create: fixedCategoryRows() } } },
      },
      include: { stores: true },
    });
    return startSession(user, user.stores);
  } catch (error) {
    // The unique phone index is what stops a double registration, even when two
    // requests arrive at once.
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      throw new ApiError({ code: "VALIDATION_FAILED", message: "Nomor ini sudah terdaftar", fields: { phone: "Nomor ini sudah terdaftar" } });
    }
    throw error;
  }
}

export async function login(input: { phone: string; password: string }): Promise<SessionJson> {
  const phone = normalisePhone(input.phone);
  // A number that is not a valid mobile still counts against itself as typed.
  const phoneKey = phone ?? input.phone.trim().toLowerCase();
  const lockRemainingMs = loginLimiter.lockRemainingMs(phoneKey, Date.now());
  if (lockRemainingMs > 0) {
    const minutes = Math.ceil(lockRemainingMs / 60_000);
    throw new ApiError({ code: "TOO_MANY_ATTEMPTS", message: `Terlalu banyak percobaan. Coba lagi dalam ${minutes} menit.` });
  }
  const user = phone === null ? null : await prisma.user.findUnique({ where: { phone }, include: { stores: { orderBy: { createdAt: "asc" } } } });
  // The same answer, and the same scrypt work, for an unknown number and a wrong
  // password, so neither the message nor the timing reveals who has an account.
  const isCorrect = await isPasswordCorrect(input.password, user?.passwordHash ?? UNKNOWN_USER_HASH);
  if (user === null || !isCorrect) {
    loginLimiter.recordFailure(phoneKey, Date.now());
    throw new ApiError({ code: "UNAUTHORIZED", message: WRONG_SIGN_IN });
  }
  loginLimiter.recordSuccess(phoneKey);
  return startSession(user, user.stores);
}

export async function getAccount(userId: string): Promise<AccountJson> {
  const user = await prisma.user.findUnique({ where: { id: userId }, include: { stores: { orderBy: { createdAt: "asc" } } } });
  if (user === null) {
    throw new ApiError({ code: "UNAUTHORIZED", message: "Silakan masuk lagi" });
  }
  return toAccountJson(user, user.stores);
}

// UU 27/2022: consent is recorded once, with its time. Giving it again keeps
// the first time.
export async function giveConsent(userId: string): Promise<{ consentAt: string }> {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (user === null) {
    throw new ApiError({ code: "UNAUTHORIZED", message: "Silakan masuk lagi" });
  }
  if (user.consentAt !== null) {
    return { consentAt: user.consentAt.toISOString() };
  }
  const updated = await prisma.user.update({ where: { id: userId }, data: { consentAt: new Date() } });
  return { consentAt: (updated.consentAt as Date).toISOString() };
}

export async function hasGivenConsent(userId: string): Promise<boolean> {
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { consentAt: true } });
  return user?.consentAt != null;
}

function startSession(user: User, stores: Store[]): SessionJson {
  const firstStore = stores[0];
  if (firstStore === undefined) {
    // Register always creates a store, so an owner without one is a data error.
    throw new Error(`user ${user.id} has no store`);
  }
  const token = signToken({ userId: user.id, storeId: firstStore.id }, { secret: config.jwtSecret, nowSeconds: Math.floor(Date.now() / 1000) });
  return { token, ...toAccountJson(user, stores) };
}

function requirePhone(typed: string): string {
  const phone = normalisePhone(typed);
  if (phone === null) {
    throw new ApiError({ code: "VALIDATION_FAILED", message: "Nomor HP tidak valid", fields: { phone: "Nomor HP tidak valid" } });
  }
  return phone;
}

function toAccountJson(user: User, stores: Store[]): AccountJson {
  return {
    user: { id: user.id, name: user.name, phone: user.phone, consentAt: user.consentAt?.toISOString() ?? null },
    stores: stores.map(toStoreJson),
  };
}
