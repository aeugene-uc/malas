// Spec §4.2: the category kinds every store has from the start. They are fixed:
// they cannot be renamed or deleted, because code relies on them (Pinjaman masuk
// opens an Utang, the not-in-profit ones get their own line in Analisis). The
// owner can add their own categories beside them.

type FixedCategory = { name: string; direction: "IN" | "OUT"; countedInProfit: boolean };

export const FIXED_CATEGORIES: FixedCategory[] = [
  { name: "Penjualan", direction: "IN", countedInProfit: true },
  { name: "Pendapatan lain", direction: "IN", countedInProfit: true },
  { name: "Barang dagangan", direction: "OUT", countedInProfit: true },
  { name: "Bahan", direction: "OUT", countedInProfit: true },
  { name: "Operasional", direction: "OUT", countedInProfit: true },
  { name: "Gaji", direction: "OUT", countedInProfit: true },
  { name: "Sewa", direction: "OUT", countedInProfit: true },
  { name: "Lainnya", direction: "OUT", countedInProfit: true },
  { name: "Modal masuk", direction: "IN", countedInProfit: false },
  { name: "Ambil pribadi", direction: "OUT", countedInProfit: false },
  { name: "Pinjaman masuk", direction: "IN", countedInProfit: false },
  { name: "Bayar pinjaman", direction: "OUT", countedInProfit: false },
  // Money held or passed through for others, both received and handed on.
  { name: "Uang titipan", direction: "IN", countedInProfit: false },
  { name: "Uang titipan", direction: "OUT", countedInProfit: false },
];

// For a nested create when a store is made.
export function fixedCategoryRows(): (FixedCategory & { fixed: true })[] {
  return FIXED_CATEGORIES.map((category) => ({ ...category, fixed: true }));
}
