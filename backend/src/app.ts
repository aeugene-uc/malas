import express, { type Express } from "express";
import { healthRouter } from "./routes/health.js";
import { handleError, handleNotFound } from "./errors.js";

export function createApp(): Express {
  const app = express();

  // A photo read sends an image, so the JSON limit is above the default 100kb.
  app.use(express.json({ limit: "10mb" }));

  app.use("/api/v1", healthRouter);

  app.use(handleNotFound);
  app.use(handleError);

  return app;
}
