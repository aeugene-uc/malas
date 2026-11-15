// Spec §10: a store's day runs from its day-change hour (default 04:00) in its
// own timezone, so a 01:00 sale stays on the previous date. Computed in code,
// never from the server clock or SQL (contract wire rule 5).

export function resolveBusinessDate(options: { now: Date; timezone: string; dayChangeHour: number }): string {
  const parts = localParts(options.now, options.timezone);
  const localDate = new Date(Date.UTC(parts.year, parts.month - 1, parts.day));
  if (parts.hour < options.dayChangeHour) {
    localDate.setUTCDate(localDate.getUTCDate() - 1);
  }
  return localDate.toISOString().slice(0, 10);
}

// "2026-11" for the calendar month the store is in, for monthly limits.
export function localYearMonth(now: Date, timezone: string): string {
  const parts = localParts(now, timezone);
  return `${parts.year}-${String(parts.month).padStart(2, "0")}`;
}

function localParts(now: Date, timezone: string): { year: number; month: number; day: number; hour: number } {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    hourCycle: "h23",
  });
  const valueByType = Object.fromEntries(formatter.formatToParts(now).map((part) => [part.type, part.value]));
  return {
    year: Number(valueByType.year),
    month: Number(valueByType.month),
    day: Number(valueByType.day),
    hour: Number(valueByType.hour),
  };
}
