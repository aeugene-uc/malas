import '../../model/analytics.dart';
import '../format.dart';

const List<String> _monthNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// "9–15 Nov 2026", "November 2026" or "2026".
String formatPeriodLabel(PeriodRange range) {
  return switch (range.period) {
    AnalyticsPeriod.minggu => _formatWeek(range),
    AnalyticsPeriod.bulan =>
      '${_monthNames[range.from.month - 1]} ${range.from.year}',
    AnalyticsPeriod.tahun => '${range.from.year}',
  };
}

/// "+12%", "-5%", or "—" when there was nothing to compare with.
String formatChange(double? change) {
  if (change == null) return '—';
  final percent = (change * 100).round();
  return percent > 0 ? '+$percent%' : '$percent%';
}

String formatShare(double share) => '${(share * 100).round()}%';

/// The WhatsApp text summary for Ekspor (§7.6). Every figure is the
/// server's, as Analisis shows it.
String buildWhatsAppSummary({
  required String storeName,
  required PeriodRange range,
  required AnalyticsSummary summary,
  required List<RankedRow> masukRows,
}) {
  final lines = [
    '$storeName · ${formatPeriodLabel(range)}',
    'Masuk ${formatRupiah(summary.masuk)} (${formatChange(summary.changes.masuk)})',
    'Keluar ${formatRupiah(summary.keluar)} (${formatChange(summary.changes.keluar)})',
    if (summary.untung case final untung?)
      'Untung ${formatRupiah(untung)} (${formatChange(summary.changes.untung)})',
    ...notCountedLines(summary.notCountedInProfit),
    '${summary.daysRecorded} dari ${summary.daysInPeriod} hari dicatat',
    'Piutang ${formatRupiah(summary.piutangAtEnd)} · '
        'Utang ${formatRupiah(summary.utangAtEnd)}',
    if (masukRows.isNotEmpty) ...[
      '',
      'Paling laku:',
      for (final row in masukRows.take(3))
        '- ${row.name} ${formatRupiah(row.amount)}',
    ],
  ];
  return lines.join('\n');
}

/// Money not counted in profit, one line per kind that moved.
List<String> notCountedLines(NotCountedInProfit notCounted) {
  return [
    for (final (label, amount) in [
      ('Modal', notCounted.modal),
      ('Ambil pribadi', notCounted.ambilPribadi),
      ('Pinjaman', notCounted.pinjaman),
      ('Titipan', notCounted.titipan),
    ])
      if (amount != 0) '$label ${formatRupiah(amount)}',
  ];
}

String _formatWeek(PeriodRange range) {
  final from = range.from;
  final to = range.to;
  final toLabel =
      '${to.day} ${_monthNames[to.month - 1].substring(0, 3)} ${to.year}';
  if (from.month == to.month) return '${from.day}–$toLabel';
  return '${from.day} ${_monthNames[from.month - 1].substring(0, 3)}–$toLabel';
}
