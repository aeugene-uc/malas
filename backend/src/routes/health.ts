import { Router } from "express";
import * as healthController from "../controllers/healthController.js";

export const healthRouter = Router();

healthRouter.get("/health", healthController.getHealth);
