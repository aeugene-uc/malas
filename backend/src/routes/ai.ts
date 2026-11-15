import { Router } from "express";
import { requireAuth, requireConsent } from "../auth.js";
import * as aiReadController from "../controllers/aiReadController.js";

export const aiRouter = Router();

// Consent first: the consent line is what allows voice and photos to go to the
// AI service (spec §7.1, UU 27/2022).
aiRouter.post("/ai/read", requireAuth, requireConsent, aiReadController.readInput);
