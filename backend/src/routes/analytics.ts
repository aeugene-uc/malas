import { Router } from "express";
import { requireAuth, requireConsent } from "../auth.js";
import * as alertController from "../controllers/alertController.js";
import * as analyticsController from "../controllers/analyticsController.js";

// Reads need a signed-in owner. Muting an alert is a write, so it also needs
// consent (UU 27/2022).
export const analyticsRouter = Router();

analyticsRouter.get("/home", requireAuth, analyticsController.home);
analyticsRouter.get("/analytics/summary", requireAuth, analyticsController.summary);
analyticsRouter.get("/analytics/by-item", requireAuth, analyticsController.byItem);
analyticsRouter.get("/analytics/by-category", requireAuth, analyticsController.byCategory);
analyticsRouter.get("/alerts", requireAuth, analyticsController.alerts);
analyticsRouter.patch("/alerts/:id", requireAuth, requireConsent, alertController.updateAlert);
