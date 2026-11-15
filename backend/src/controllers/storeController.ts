import { readAuth } from "../auth.js";
import { handleAsync } from "../errors.js";
import * as storeService from "../services/storeService.js";
import type { StoreChanges } from "../services/storeService.js";
import { readBody, readName, throwIfInvalid, type FieldErrors } from "./validate.js";

// The wire values F2 sends for "Usaha kamu apa?" (#173).
const BUSINESS_TYPES = ["MAKANAN_MINUMAN", "JUALAN_BARANG", "BIKIN_PESANAN", "JASA", "SEWA", "ANTAR_OJEK", "TANI_TERNAK_IKAN", "AGEN"];
// Indonesia's three zones: WIB, WITA, WIT.
const TIMEZONES = ["Asia/Jakarta", "Asia/Makassar", "Asia/Jayapura"];
const PLANS = ["GRATIS", "PRO", "PRO_PLUS"] as const;
const REMINDER_TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
// F9 offers a day change from 00:00 to 06:00.
const MAX_DAY_CHANGE_HOUR = 6;

export const getStore = handleAsync(async (req, res) => {
  storeService.requireOwnStore(String(req.params.id), readAuth(res).storeId);
  res.json({ store: await storeService.getStore(readAuth(res).storeId) });
});

export const updateStore = handleAsync(async (req, res) => {
  storeService.requireOwnStore(String(req.params.id), readAuth(res).storeId);
  const changes = readStoreChanges(readBody(req));
  res.json({ store: await storeService.updateStore(readAuth(res).storeId, changes) });
});

// Only the fields present are checked and changed. Unknown fields are ignored.
export function readStoreChanges(body: Record<string, unknown>): StoreChanges {
  const fields: FieldErrors = {};
  const changes: StoreChanges = {};
  if ("name" in body) {
    const name = readName(body.name, "name", fields);
    if (name !== undefined) changes.name = name;
  }
  if ("businessTypes" in body) {
    const types = body.businessTypes;
    // Spec §7.1: "pick one or more".
    if (!Array.isArray(types) || types.length === 0 || !types.every((type) => BUSINESS_TYPES.includes(type)) || new Set(types).size !== types.length) {
      fields.businessTypes = "Pilih jenis usaha";
    } else {
      changes.businessTypes = types as string[];
    }
  }
  if ("closedDays" in body) {
    const days = body.closedDays;
    // ISO weekdays, 1 is Monday (#176). A store open no day at all is not a store.
    const isValid = Array.isArray(days) && days.length <= 6 && days.every((day) => Number.isInteger(day) && day >= 1 && day <= 7) && new Set(days).size === days.length;
    if (isValid) {
      changes.closedDays = [...(days as number[])].sort((a, b) => a - b);
    } else {
      fields.closedDays = "Hari tutup tidak valid";
    }
  }
  if ("timezone" in body) {
    if (typeof body.timezone === "string" && TIMEZONES.includes(body.timezone)) {
      changes.timezone = body.timezone;
    } else {
      fields.timezone = "Zona waktu tidak valid";
    }
  }
  if ("dayChangeHour" in body) {
    const hour = body.dayChangeHour;
    if (typeof hour === "number" && Number.isInteger(hour) && hour >= 0 && hour <= MAX_DAY_CHANGE_HOUR) {
      changes.dayChangeHour = hour;
    } else {
      fields.dayChangeHour = "Jam ganti hari tidak valid";
    }
  }
  if ("reminderTime" in body) {
    const time = body.reminderTime;
    if (time === null || (typeof time === "string" && REMINDER_TIME.test(time))) {
      changes.reminderTime = time;
    } else {
      fields.reminderTime = "Jam pengingat tidak valid";
    }
  }
  if ("alertsOn" in body) {
    if (typeof body.alertsOn === "boolean") {
      changes.alertsOn = body.alertsOn;
    } else {
      fields.alertsOn = "Pilih nyala atau mati";
    }
  }
  if ("plan" in body) {
    // Spec §18: the December test has no billing, so a plan is simply chosen.
    const plan = PLANS.find((candidate) => candidate === body.plan);
    if (plan === undefined) {
      fields.plan = "Paket tidak dikenal";
    } else {
      changes.plan = plan;
    }
  }
  throwIfInvalid(fields);
  return changes;
}
