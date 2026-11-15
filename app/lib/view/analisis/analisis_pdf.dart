import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../model/analytics.dart';
import '../format.dart';
import 'analisis_text.dart';

/// The Ekspor PDF for one period (§7.6), built on the phone from the figures
/// Analisis already shows. It states days recorded and edited entries (§15).
Future<Uint8List> buildAnalisisPdf({
  required String storeName,
  required PeriodRange range,
  required AnalyticsSummary summary,
  required List<RankedRow> masukRows,
  required List<RankedRow> keluarRows,
}) {
  final document = pw.Document(title: '$storeName ${formatPeriodLabel(range)}');
  document.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Header(level: 0, text: storeName),
        pw.Text(formatPeriodLabel(range)),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['', 'Jumlah', 'Perubahan'],
          data: [
            _figureRow('Masuk', summary.masuk, summary.changes.masuk),
            _figureRow('Keluar', summary.keluar, summary.changes.keluar),
            if (summary.untung case final untung?)
              _figureRow('Untung', untung, summary.changes.untung),
          ],
        ),
        for (final line in notCountedLines(summary.notCountedInProfit))
          pw.Text(line),
        pw.SizedBox(height: 12),
        pw.Text(
          '${summary.daysRecorded} dari ${summary.daysInPeriod} hari dicatat',
        ),
        pw.Text('${summary.editedEntryCount} catatan diubah'),
        pw.Text(
          'Piutang ${formatRupiah(summary.piutangAtEnd)} · '
          'Utang ${formatRupiah(summary.utangAtEnd)}',
        ),
        ..._rankedTable('Masuk per barang', masukRows),
        ..._rankedTable('Keluar per kategori', keluarRows),
      ],
    ),
  );
  return document.save();
}

List<String> _figureRow(String label, int amount, double? change) {
  return [label, formatRupiah(amount), formatChange(change)];
}

List<pw.Widget> _rankedTable(String title, List<RankedRow> rows) {
  if (rows.isEmpty) return const [];
  return [
    pw.SizedBox(height: 16),
    pw.Header(level: 1, text: title),
    pw.TableHelper.fromTextArray(
      headers: ['', 'Jumlah', 'Bagian'],
      data: [
        for (final row in rows)
          [row.name, formatRupiah(row.amount), formatShare(row.share)],
      ],
    ),
  ];
}
