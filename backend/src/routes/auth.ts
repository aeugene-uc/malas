import { Router } from "express";
import { requireAuth } from "../auth.js";
import * as authController from "../controllers/authController.js";

export const authRouter = Router();

authRouter.post("/auth/register", authController.register);
authRouter.post("/auth/login", authController.login);
authRouter.get("/auth/me", requireAuth, authController.me);
// Consent itself cannot sit behind requireConsent.
authRouter.post("/auth/consent", requireAuth, authController.consent);
