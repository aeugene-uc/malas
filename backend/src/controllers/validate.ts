import type { Request } from "express";
import { ApiError } from "../errors.js";

// Request bodies are a trust boundary (CLAUDE.md). Each check adds an Indonesian
// message under its field, and throwIfInvalid answers 400 with all of them, so
// the app can mark every wrong field at once.

export type FieldErrors = Record<string, string>;

export function readBody(req: Request): Record<string, unknown> {
  const body = typeof req.body === "object" && req.body !== null && !Array.isArray(req.body) ? (req.body as Record<string, unknown>) : {};
  // Contract wire rule 4: the store always comes from the token.
  if ("storeId" in body) {
    throw new ApiError({ code: "VALIDATION_FAILED", message: "storeId tidak boleh dikirim", fields: { storeId: "storeId tidak boleh dikirim" } });
  }
  return body;
}

export function throwIfInvalid(fields: FieldErrors): void {
  const firstMessage = Object.values(fields)[0];
  if (firstMessage !== undefined) {
    throw new ApiError({ code: "VALIDATION_FAILED", message: firstMessage, fields });
  }
}

// A trimmed name of 1 to maxLength characters, or undefined (and an error) when
// it is not one.
export function readName(value: unknown, field: string, fields: FieldErrors, maxLength = 80): string | undefined {
  const name = typeof value === "string" ? value.trim() : "";
  if (name === "" || name.length > maxLength) {
    fields[field] = "Isi nama";
    return undefined;
  }
  return name;
}

// Whole rupiah from 0 up to Rp 10.000.000, the price ceiling of spec §9.
export function readPrice(value: unknown, field: string, fields: FieldErrors): number | null | undefined {
  if (value === null) {
    return null;
  }
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0 || value > 10_000_000) {
    fields[field] = "Harga tidak valid";
    return undefined;
  }
  return value;
}
