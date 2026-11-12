// Spec §7.3 and §9: number words are converted by code from a fixed list, never
// by the model. Values are kept in thousandths so "setengah" and "1,2 juta" stay
// exact without floats, matching Line.quantity's Decimal(12, 3).

export const UNITS = ["porsi", "pcs", "kg", "liter", "lembar", "jam", "malam", "bulan", "paket"] as const;

export type Unit = (typeof UNITS)[number];

export type Quantity = { quantity: string; unit: Unit | null };

type Thousandths = number;

const SCALE = 1000;

// Rupiah amounts that are complete on their own ("es teh goceng").
const rupiahBySlang: Record<string, number> = {
  cepek: 100,
  gopek: 500,
  seceng: 1_000,
  noceng: 2_000,
  goceng: 5_000,
  ceban: 10_000,
  goban: 50_000,
};

const valueByWord: Record<string, number> = {
  nol: 0,
  satu: 1,
  dua: 2,
  tiga: 3,
  empat: 4,
  lima: 5,
  enam: 6,
  tujuh: 7,
  delapan: 8,
  sembilan: 9,
  sebelas: 11,
  selawe: 25,
  seket: 50,
  setengah: 0.5,
  seperempat: 0.25,
};

// "se-" means one: "seratus" is "satu ratus".
const wordsBySePrefixed: Record<string, string[]> = {
  sepuluh: ["satu", "puluh"],
  seratus: ["satu", "ratus"],
  seribu: ["satu", "ribu"],
  sejuta: ["satu", "juta"],
};

const multiplierByWord: Record<string, number> = {
  ribu: 1_000,
  rb: 1_000,
  k: 1_000,
  juta: 1_000_000,
  jt: 1_000_000,
  miliar: 1_000_000_000,
  milyar: 1_000_000_000,
};

// factor is in thousandths of the unit: one ons is 0.1 kg.
const unitByWord: Record<string, { unit: Unit; factor: number }> = {
  porsi: { unit: "porsi", factor: 1_000 },
  pcs: { unit: "pcs", factor: 1_000 },
  biji: { unit: "pcs", factor: 1_000 },
  buah: { unit: "pcs", factor: 1_000 },
  kg: { unit: "kg", factor: 1_000 },
  kilo: { unit: "kg", factor: 1_000 },
  ons: { unit: "kg", factor: 100 },
  liter: { unit: "liter", factor: 1_000 },
  lembar: { unit: "lembar", factor: 1_000 },
  jam: { unit: "jam", factor: 1_000 },
  malam: { unit: "malam", factor: 1_000 },
  bulan: { unit: "bulan", factor: 1_000 },
  paket: { unit: "paket", factor: 1_000 },
};

// True when the text carries a sign that it is money: ribu, juta, Rp, slang like
// goceng, or digits grouped as 25.000. A bare number or number word after an item
// ("es teh selawe") has none of these and is a quantity (spec §7.3).
export function hasMoneyMarker(text: string): boolean {
  return tokenize(text).some(
    (word) =>
      word === "rp" ||
      Object.hasOwn(rupiahBySlang, word) ||
      Object.hasOwn(multiplierByWord, word) ||
      /^\d{1,3}(\.\d{3})+$/.test(word),
  );
}

// Returns integer rupiah, or null when the text is not a clear amount, so the
// draft highlights it instead of guessing.
export function parseRupiah(text: string): number | null {
  const words = tokenize(text).filter((word) => word !== "rp");
  const onlyWord = words.length === 1 ? words[0] : undefined;
  if (onlyWord !== undefined && onlyWord in rupiahBySlang) {
    return rupiahBySlang[onlyWord] ?? null;
  }
  const value = parseWords(words);
  if (value === null || value % SCALE !== 0) {
    return null;
  }
  return value / SCALE;
}

// "setengah kilo" becomes { quantity: "0.5", unit: "kg" }. A bare number is a
// quantity with no unit (spec §7.3).
export function parseQuantity(text: string): Quantity | null {
  const words = tokenize(text);
  const lastWord = words.at(-1) ?? "";
  const unitMatch = unitByWord[lastWord] ?? matchSePrefixedUnit(lastWord);
  if (unitMatch === undefined) {
    return toQuantity(parseWords(words), null, SCALE);
  }
  const numberWords = words.slice(0, -1);
  const value = lastWord in unitByWord ? parseWords(numberWords) : numberWords.length === 0 ? SCALE : null;
  return toQuantity(value, unitMatch.unit, unitMatch.factor);
}

function toQuantity(value: Thousandths | null, unit: Unit | null, factor: number): Quantity | null {
  if (value === null || value === 0) {
    return null;
  }
  const inUnit = (value * factor) / SCALE;
  if (!Number.isInteger(inUnit)) {
    return null;
  }
  return { quantity: formatThousandths(inUnit), unit };
}

// "sekilo" is one kilo.
function matchSePrefixedUnit(word: string): { unit: Unit; factor: number } | undefined {
  return word.startsWith("se") ? unitByWord[word.slice(2)] : undefined;
}

function tokenize(text: string): string[] {
  const separated = text
    .toLowerCase()
    .replace(/(\d)([a-z])/g, "$1 $2")
    .replace(/([a-z])(\d)/g, "$1 $2");
  return separated.split(/\s+/).filter((word) => word !== "").flatMap((word) => wordsBySePrefixed[word] ?? [word]);
}

// Builds the number left to right: "dua ratus lima puluh ribu" is 250 x 1000.
// `group` holds the part below the next ribu/juta, `lastValue` the most recent
// digit word, which "puluh" and "ratus" scale.
function parseWords(words: string[]): Thousandths | null {
  if (words.length === 0) {
    return null;
  }
  let total: Thousandths = 0;
  let group: Thousandths = 0;
  let lastValue: Thousandths | null = null;

  for (const word of words) {
    const value = parseDigits(word) ?? toThousandths(valueByWord[word]);
    if (value !== null) {
      group += value;
      lastValue = value;
      continue;
    }
    if (word === "belas" && lastValue !== null) {
      group += 10 * SCALE;
      lastValue = null;
      continue;
    }
    const scaleBy = word === "puluh" ? 10 : word === "ratus" ? 100 : null;
    if (scaleBy !== null && lastValue !== null) {
      group += lastValue * (scaleBy - 1);
      lastValue = null;
      continue;
    }
    const multiplier = multiplierByWord[word];
    if (multiplier === undefined) {
      return null;
    }
    total += (group === 0 ? SCALE : group) * multiplier;
    group = 0;
    lastValue = null;
  }
  return total + group;
}

function toThousandths(value: number | undefined): Thousandths | null {
  return value === undefined ? null : Math.round(value * SCALE);
}

// Indonesian writing: "25.000" is twenty-five thousand and "1,2" is one point
// two. A dot is a thousands separator only before groups of exactly 3 digits.
function parseDigits(word: string): Thousandths | null {
  const thousandsSeparated = /^\d{1,3}(\.\d{3})+$/.test(word);
  const normalised = thousandsSeparated ? word.replaceAll(".", "") : word.replace(",", ".");
  const match = /^(\d+)(?:\.(\d{1,3}))?$/.exec(normalised);
  if (match === null) {
    return null;
  }
  const whole = Number(match[1]);
  const fraction = Number((match[2] ?? "").padEnd(3, "0"));
  return whole * SCALE + fraction;
}

function formatThousandths(value: Thousandths): string {
  const whole = Math.trunc(value / SCALE);
  const fraction = String(value % SCALE).padStart(3, "0").replace(/0+$/, "");
  return fraction === "" ? String(whole) : `${whole}.${fraction}`;
}
