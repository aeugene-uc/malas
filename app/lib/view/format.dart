import 'package:flutter/services.dart';

/// Money as spec §5.8 shows it: `Rp 12.500`, a dot between thousands.
String formatRupiah(int amount) {
  final sign = amount < 0 ? '-' : '';
  return '${sign}Rp ${groupThousands(amount.abs())}';
}

/// `1200000` as `1.200.000`.
String groupThousands(int amount) {
  final digits = amount.toString();
  final groupedDigits = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final digitsLeft = digits.length - index;
    if (index > 0 && digitsLeft % 3 == 0) groupedDigits.write('.');
    groupedDigits.write(digits[index]);
  }
  return groupedDigits.toString();
}

/// Groups a rupiah amount with dots while it is typed, so "1200000" reads
/// "1.200.000" (§5.8). The cursor stays after the same digit.
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _digitsOf(newValue.text);
    if (digits.isEmpty) return TextEditingValue.empty;
    final text = groupThousands(int.parse(digits));
    final cursor = newValue.selection.isValid
        ? newValue.selection.end
        : newValue.text.length;
    final digitsBeforeCursor = _digitsOf(newValue.text.substring(0, cursor))
        .length;
    var offset = 0;
    var digitsPassed = 0;
    while (offset < text.length && digitsPassed < digitsBeforeCursor) {
      if (text[offset] != '.') digitsPassed++;
      offset++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  String _digitsOf(String text) => text.replaceAll(RegExp(r'[^0-9]'), '');
}

const List<String> _weekdayShortNames = [
  'Sen',
  'Sel',
  'Rab',
  'Kam',
  'Jum',
  'Sab',
  'Min',
];

/// The short Indonesian weekday of a `YYYY-MM-DD` business date, as in
/// "Belum dicatat: Sel, Rab". The date is read as a calendar date, with no
/// time zone, so it can't shift a day.
String formatWeekdayShort(String businessDate) {
  final date = DateTime.parse(businessDate);
  return formatIsoWeekdayShort(date.weekday);
}

/// "Sen" for 1 (Monday) to "Min" for 7, as [DateTime.weekday] numbers days.
String formatIsoWeekdayShort(int weekday) {
  return _weekdayShortNames[weekday - DateTime.monday];
}
