import type { Request } from "express";
import { readAuth } from "../auth.js";
import { ApiError, handleAsync } from "../errors.js";
import * as authService from "../services/authService.js";

const MIN_PASSWORD_LENGTH = 6;
const MAX_NAME_LENGTH = 80;

export const register = handleAsync(async (req, res) => {
  const body = readBody(req);
  const fields: Record<string, string> = {};
  const name = typeof body.name === "string" ? body.name.trim() : "";
  if (name === "" || name.length > MAX_NAME_LENGTH) {
    fields.name = "Isi nama";
  }
  collectSignInErrors(body, fields);
  throwIfInvalid(fields);
  res.status(201).json(await authService.register({ name, phone: body.phone as string, password: body.password as string }));
});

export const login = handleAsync(async (req, res) => {
  const body = readBody(req);
  const fields: Record<string, string> = {};
  collectSignInErrors(body, fields);
  throwIfInvalid(fields);
  res.json(await authService.login({ phone: body.phone as string, password: body.password as string }));
});

export const me = handleAsync(async (_req, res) => {
  res.json(await authService.getAccount(readAuth(res).userId));
});

// F2 sends no body: tapping Setuju is the consent.
export const consent = handleAsync(async (_req, res) => {
  res.json(await authService.giveConsent(readAuth(res).userId));
});

function readBody(req: Request): Record<string, unknown> {
  return typeof req.body === "object" && req.body !== null ? (req.body as Record<string, unknown>) : {};
}

function collectSignInErrors(body: Record<string, unknown>, fields: Record<string, string>): void {
  if (typeof body.phone !== "string" || body.phone.trim() === "") {
    fields.phone = "Isi nomor HP";
  }
  if (typeof body.password !== "string" || body.password.length < MIN_PASSWORD_LENGTH) {
    fields.password = `Kata sandi minimal ${MIN_PASSWORD_LENGTH} karakter`;
  }
}

function throwIfInvalid(fields: Record<string, string>): void {
  const firstMessage = Object.values(fields)[0];
  if (firstMessage !== undefined) {
    throw new ApiError({ code: "VALIDATION_FAILED", message: firstMessage, fields });
  }
}

