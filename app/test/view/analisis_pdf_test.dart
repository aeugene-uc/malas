import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/analytics.dart';
import 'package:malas/view/analisis/analisis_pdf.dart';

void main() {
  test('buildsAPdfForThePeriod', () async {
    final summary = AnalyticsSummary.fromJson(
      mockBodiesByRoute['GET /analytics/summary']! as Map<String, Object?>,
    );
    const rows = [
      RankedRow(
        id: 'item-1',
        name: 'Nasi goreng',
        amount: 4500000,
        share: 0.52,
      ),
    ];

    final pdfBytes = await buildAnalisisPdf(
      storeName: 'Warung Bu Sari',
      range: PeriodRange.containing(
        period: AnalyticsPeriod.minggu,
        date: DateTime(2026, 11, 15),
      ),
      summary: summary,
      masukRows: rows,
      keluarRows: const [],
    );

    expect(ascii.decode(pdfBytes.sublist(0, 4)), '%PDF');
    expect(pdfBytes.length, greaterThan(1000));
  });

  test('readsTheEditedEntryCountForThePdf', () {
    final summary = AnalyticsSummary.fromJson(
      mockBodiesByRoute['GET /analytics/summary']! as Map<String, Object?>,
    );

    expect(summary.editedEntryCount, 2);
  });
}
