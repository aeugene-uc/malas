import { Router } from "express";
import { requireAuth, requireConsent } from "../auth.js";
import * as transactionController from "../controllers/transactionController.js";

export const transactionRouter = Router();

transactionRouter.post("/transactions", requireAuth, requireConsent, transactionController.saveTransaction);
