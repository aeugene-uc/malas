/// Money as spec §5.8 shows it: `Rp 12.500`, a dot between thousands.
String formatRupiah(int amount) {
  final digits = amount.abs().toString();
  final groupedDigits = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final digitsLeft = digits.length - index;
    if (index > 0 && digitsLeft % 3 == 0) groupedDigits.write('.');
    groupedDigits.write(digits[index]);
  }
  final sign = amount < 0 ? '-' : '';
  return '${sign}Rp $groupedDigits';
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
  return _weekdayShortNames[date.weekday - DateTime.monday];
}
