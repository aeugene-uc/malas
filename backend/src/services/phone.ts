// Sign-in is by phone number (#100). The owner types it however they like, and
// it is stored in E.164 (+62...) so the same person cannot register twice as
// 0812... and +62812... (#104).

// Indonesian mobile numbers: +62 8, then 8 to 11 more digits.
const INDONESIAN_MOBILE = /^\+628\d{8,11}$/;

// Returns the number in E.164, or null when it is not an Indonesian mobile number.
export function normalisePhone(typed: string): string | null {
  const digits = typed.replace(/[\s\-().]/g, "");
  let e164: string;
  if (digits.startsWith("+62")) {
    e164 = digits;
  } else if (digits.startsWith("62")) {
    e164 = `+${digits}`;
  } else if (digits.startsWith("0")) {
    e164 = `+62${digits.slice(1)}`;
  } else if (digits.startsWith("8")) {
    e164 = `+62${digits}`;
  } else {
    return null;
  }
  return INDONESIAN_MOBILE.test(e164) ? e164 : null;
}
