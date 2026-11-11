// Spec §5.4: never block a save. Missing or unclear fields are flagged, not
// required, so a write returns the saved row plus these warnings.

export type WarningCode =
  | "DUPLICATE_SUSPECTED"
  | "LUMP_SUM_WITH_ITEMISED"
  | "PRICE_IMPLAUSIBLE"
  | "ITEM_NO_PRICE"
  | "TOTAL_MISMATCH"
  | "OVERPAID";

export type Warning = {
  code: WarningCode;
  message: string;
  transactionId?: string;
  lineId?: string;
};

// Owner-facing, so Bahasa Indonesia.
const messageByCode: Record<WarningCode, string> = {
  DUPLICATE_SUSPECTED: "Sepertinya catatan ini sudah ada",
  LUMP_SUM_WITH_ITEMISED: "Sudah ada penjualan rinci hari ini",
  PRICE_IMPLAUSIBLE: "Harganya jauh dari biasanya",
  ITEM_NO_PRICE: "Harga belum ada",
  TOTAL_MISMATCH: "Total tidak sama dengan jumlah baris",
  OVERPAID: "Bayarnya lebih, sisanya dikembalikan",
};

export function buildWarning(code: WarningCode, ids: Omit<Warning, "code" | "message"> = {}): Warning {
  return { code, message: messageByCode[code], ...ids };
}
