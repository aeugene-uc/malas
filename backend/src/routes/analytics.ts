import { Router } from "express";
import { requireAuth } from "../auth.js";
import * as analyticsController from "../controllers/analyticsController.js";

// Reads only, so a signed-in owner is enough.
export const analyticsRouter = Router();

analyticsRouter.get("/home", requireAuth, analyticsController.home);
analyticsRouter.get("/analytics/summary", requireAuth, analyticsController.summary);
analyticsRouter.get("/analytics/by-item", requireAuth, analyticsController.byItem);
analyticsRouter.get("/analytics/by-category", requireAuth, analyticsController.byCategory);
analyticsRouter.get("/alerts", requireAuth, analyticsController.alerts);
