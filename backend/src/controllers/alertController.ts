import { readAuth } from "../auth.js";
import { handleAsync } from "../errors.js";
import * as alertService from "../services/alertService.js";
import type { AlertChanges } from "../services/alertService.js";
import { readBody, throwIfInvalid, type FieldErrors } from "./validate.js";

export const updateAlert = handleAsync(async (req, res) => {
  const changes = readAlertChanges(readBody(req));
  res.json({ alert: await alertService.updateAlert({ storeId: readAuth(res).storeId, alertId: String(req.params.id), changes }) });
});

// Only the fields present are changed. An empty change is refused, since the
// app sends this only from a button.
export function readAlertChanges(body: Record<string, unknown>): AlertChanges {
  const fields: FieldErrors = {};
  const changes: AlertChanges = {};
  for (const name of ["seen", "muted"] as const) {
    if (!(name in body)) continue;
    if (typeof body[name] === "boolean") {
      changes[name] = body[name];
    } else {
      fields[name] = "Pilih ya atau tidak";
    }
  }
  if (Object.keys(changes).length === 0 && Object.keys(fields).length === 0) {
    fields.muted = "Tidak ada yang diubah";
  }
  throwIfInvalid(fields);
  return changes;
}
