import express, { type Express } from "express";
import { aiRouter } from "./routes/ai.js";
import { authRouter } from "./routes/auth.js";
import { healthRouter } from "./routes/health.js";
import { handleError, handleNotFound } from "./errors.js";

export function createApp(): Express {
  const app = express();

  // A photo read sends an image, so the JSON limit is above the default 100kb.
  app.use(express.json({ limit: "10mb" }));

  app.use("/api/v1", healthRouter);
  app.use("/api/v1", authRouter);
  app.use("/api/v1", aiRouter);

  app.use(handleNotFound);
  app.use(handleError);

  return app;
}
