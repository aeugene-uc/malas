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
  final periodLabel = pdfSafe(formatPeriodLabel(range));
  final document = pw.Document(title: '$storeName $periodLabel');
  document.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Header(level: 0, text: storeName),
        pw.Text(periodLabel),
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
        pw.SizedBox(height: 8),
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

/// The PDF's built-in Helvetica has no en or em dash, which show as boxes.
/// The WhatsApp text keeps them, since phones render them.
String pdfSafe(String text) {
  return text.replaceAll('–', '-').replaceAll('—', '-');
}

List<String> _figureRow(String label, int amount, double? change) {
  return [label, formatRupiah(amount), pdfSafe(formatChange(change))];
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
