import { Router } from "express";
import { requireAuth, requireConsent } from "../auth.js";
import * as transactionController from "../controllers/transactionController.js";

// Simpan (S5) and Catatan (S6). Reading needs a signed-in owner; every write
// also needs consent (UU 27/2022). Ulangi and Retur only build a draft, so they
// are reads.

export const transactionRouter = Router();

transactionRouter.post("/transactions", requireAuth, requireConsent, transactionController.saveTransaction);
transactionRouter.get("/transactions", requireAuth, transactionController.listTransactions);
transactionRouter.get("/transactions/:id", requireAuth, transactionController.getTransaction);
transactionRouter.patch("/transactions/:id", requireAuth, requireConsent, transactionController.editTransaction);
transactionRouter.delete("/transactions/:id", requireAuth, requireConsent, transactionController.deleteTransaction);
transactionRouter.post("/transactions/:id/restore", requireAuth, requireConsent, transactionController.restoreTransaction);
transactionRouter.get("/transactions/:id/history", requireAuth, transactionController.getHistory);
transactionRouter.post("/transactions/:id/payments", requireAuth, requireConsent, transactionController.payTransaction);
transactionRouter.delete("/payments/:id", requireAuth, requireConsent, transactionController.deletePayment);
transactionRouter.post("/transactions/:id/repeat", requireAuth, transactionController.repeatTransaction);
transactionRouter.post("/transactions/:id/retur", requireAuth, transactionController.returTransaction);
transactionRouter.get("/receivables", requireAuth, transactionController.listReceivables);
transactionRouter.get("/payables", requireAuth, transactionController.listPayables);
