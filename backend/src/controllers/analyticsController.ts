import type { Request } from "express";
import { readAuth } from "../auth.js";
import { handleAsync } from "../errors.js";
import type { AnalysisPeriod } from "../services/analytics.js";
import * as analyticsService from "../services/analyticsService.js";
import { throwIfInvalid, type FieldErrors } from "./validate.js";

// Beranda (F4) and Analisis (F7) read these. F7 sends ?period=minggu|bulan|tahun
// &from=YYYY-MM-DD, plus direction=IN|OUT for the ranked lists (#179).

const PERIODS: AnalysisPeriod[] = ["minggu", "bulan", "tahun"];

export const home = handleAsync(async (_req, res) => {
  res.json(await analyticsService.getHome(readAuth(res).storeId));
});

export const summary = handleAsync(async (req, res) => {
  const { period, start } = readPeriodQuery(req);
  res.json(await analyticsService.getSummary(readAuth(res).storeId, period, start));
});

export const byItem = handleAsync(async (req, res) => {
  const { period, start } = readPeriodQuery(req);
  const direction = req.query.direction === "OUT" ? "OUT" : "IN";
  res.json({ rows: await analyticsService.getRankedRows(readAuth(res).storeId, { period, start, direction, mode: "item" }) });
});

export const byCategory = handleAsync(async (req, res) => {
  const { period, start } = readPeriodQuery(req);
  const direction = req.query.direction === "IN" ? "IN" : "OUT";
  res.json({ rows: await analyticsService.getRankedRows(readAuth(res).storeId, { period, start, direction, mode: "category" }) });
});

export const alerts = handleAsync(async (_req, res) => {
  res.json({ alerts: await analyticsService.getAlerts(readAuth(res).storeId) });
});

export function readPeriodQuery(req: Pick<Request, "query">): { period: AnalysisPeriod; start: string } {
  const fields: FieldErrors = {};
  const period = PERIODS.find((candidate) => candidate === req.query.period);
  if (period === undefined) {
    fields.period = "Pilih minggu, bulan atau tahun";
  }
  const start = typeof req.query.from === "string" ? req.query.from : "";
  if (!isRealDate(start)) {
    fields.from = "Tanggal tidak valid";
  }
  throwIfInvalid(fields);
  return { period: period as AnalysisPeriod, start };
}

function isRealDate(date: string): boolean {
  const parsed = new Date(`${date}T00:00:00Z`);
  return /^\d{4}-\d{2}-\d{2}$/.test(date) && !Number.isNaN(parsed.getTime()) && parsed.toISOString().startsWith(date);
}
