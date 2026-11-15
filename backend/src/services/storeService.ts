import type { Prisma, Store } from "@prisma/client";
import { prisma } from "../db.js";
import { ApiError } from "../errors.js";

// The store's own settings (spec §6, §7.1): what first-run setup (F2) and
// Settings (F9) send with PATCH /stores/:id.

export type StoreJson = {
  id: string;
  name: string;
  businessTypes: Prisma.JsonValue;
  closedDays: Prisma.JsonValue;
  timezone: string;
  dayChangeHour: number;
  reminderTime: string | null;
  alertsOn: boolean;
  plan: Store["plan"];
  trialEndsAt: string | null;
};

// Every field is optional: setup sends name and businessTypes, Settings the rest.
export type StoreChanges = Partial<{
  name: string;
  businessTypes: string[];
  closedDays: number[];
  timezone: string;
  dayChangeHour: number;
  reminderTime: string | null;
  alertsOn: boolean;
  plan: Store["plan"];
}>;

export async function getStore(storeId: string): Promise<StoreJson> {
  return toStoreJson(await prisma.store.findUniqueOrThrow({ where: { id: storeId } }));
}

export async function updateStore(storeId: string, changes: StoreChanges): Promise<StoreJson> {
  return toStoreJson(await prisma.store.update({ where: { id: storeId }, data: changes }));
}

// A store can only be reached through the owner's own token. Another store's id
// answers as not found, so ids cannot be probed.
export function requireOwnStore(requestedId: string, tokenStoreId: string): void {
  if (requestedId !== tokenStoreId) {
    throw new ApiError({ code: "NOT_FOUND", message: "Toko tidak ditemukan" });
  }
}

export function toStoreJson(store: Store): StoreJson {
  return {
    id: store.id,
    name: store.name,
    businessTypes: store.businessTypes,
    closedDays: store.closedDays,
    timezone: store.timezone,
    dayChangeHour: store.dayChangeHour,
    reminderTime: store.reminderTime,
    alertsOn: store.alertsOn,
    plan: store.plan,
    trialEndsAt: store.trialEndsAt?.toISOString() ?? null,
  };
}
