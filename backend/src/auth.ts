import type { NextFunction, Request, Response } from "express";
import { config } from "./config.js";
import { ApiError, handleAsync } from "./errors.js";
import * as authService from "./services/authService.js";
import { readToken, type TokenClaims } from "./services/token.js";

// The two gates every owner route sits behind. requireAuth puts the owner and
// their store on res.locals, which is the only place routes take storeId from
// (contract wire rule 4). requireConsent blocks every write until the owner has
// accepted the consent line (UU 27/2022).

export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const header = req.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice("Bearer ".length) : "";
  const claims = readToken(token, { secret: config.jwtSecret, nowSeconds: Math.floor(Date.now() / 1000) });
  if (claims === null) {
    next(new ApiError({ code: "UNAUTHORIZED", message: "Silakan masuk lagi" }));
    return;
  }
  res.locals.auth = claims;
  next();
}

export const requireConsent = handleAsync(async (_req, res, next) => {
  if (!(await authService.hasGivenConsent(readAuth(res).userId))) {
    throw new ApiError({ code: "CONSENT_REQUIRED", message: "Setujui dulu penggunaan data" });
  }
  next();
});

export function readAuth(res: Response): TokenClaims {
  return res.locals.auth as TokenClaims;
}
