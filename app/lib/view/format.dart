import '../model/transaction.dart';

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
  return formatIsoWeekdayShort(date.weekday);
}

/// "Sen" for 1 (Monday) to "Min" for 7, as [DateTime.weekday] numbers days.
String formatIsoWeekdayShort(int weekday) {
  return _weekdayShortNames[weekday - DateTime.monday];
}

/// "Nasi goreng 2 porsi, Es teh 4 gelas", with the person first when there
/// is one. Beranda, Catatan and Piutang/Utang all describe entries this way.
String describeEntry(Transaction entry) {
  final lineDescriptions = entry.lines.map(describeLine).join(', ');
  final person = entry.person;
  if (person == null) return lineDescriptions;
  return lineDescriptions.isEmpty
      ? person.name
      : '${person.name} · $lineDescriptions';
}

/// "Nasi goreng 2 porsi". A bare amount is named by its category.
String describeLine(TransactionLine line) {
  // A bare amount has no item, so its category is the only name it has.
  final name = line.item?.name ?? line.category?.name ?? '';
  final quantity = line.quantity;
  if (quantity == null) return name;
  final unit = line.unit;
  return unit == null ? '$name $quantity' : '$name $quantity $unit';
}
