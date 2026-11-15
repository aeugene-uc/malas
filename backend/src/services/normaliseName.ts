// One rule for comparing item and person names, so "Kopi  Susu" and "kopi susu"
// are the same item. Item.normalisedName is stored with this rule (S4), and the
// AI read matches spoken names with it (spec §7.3, §9).
export function normaliseName(name: string): string {
  return name.toLowerCase().replace(/\s+/g, " ").trim();
}
