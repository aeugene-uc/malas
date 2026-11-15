import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/analytics.dart';
import 'package:malas/view/analisis/analisis_text.dart';

void main() {
  test('labelsEachKindOfPeriod', () {
    PeriodRange rangeOf(AnalyticsPeriod period, DateTime date) =>
        PeriodRange.containing(period: period, date: date);

    expect(
      formatPeriodLabel(
        rangeOf(AnalyticsPeriod.minggu, DateTime(2026, 11, 15)),
      ),
      '9–15 Nov 2026',
    );
    expect(
      formatPeriodLabel(rangeOf(AnalyticsPeriod.minggu, DateTime(2026, 12, 1))),
      '30 Nov–6 Des 2026',
    );
    expect(
      formatPeriodLabel(rangeOf(AnalyticsPeriod.bulan, DateTime(2026, 11, 15))),
      'November 2026',
    );
    expect(
      formatPeriodLabel(rangeOf(AnalyticsPeriod.tahun, DateTime(2026, 11, 15))),
      '2026',
    );
  });

  test('showsChangeAsASignedPercentOrADashForNothingToCompare', () {
    expect(formatChange(0.12), '+12%');
    expect(formatChange(-0.054), '-5%');
    expect(formatChange(0), '0%');
    expect(formatChange(null), '—');
  });

  test('theWhatsAppSummaryUsesTheServersFigures', () {
    final summary = AnalyticsSummary.fromJson(
      mockBodiesByRoute['GET /analytics/summary']! as Map<String, Object?>,
    );
    final masukRows = [
      const RankedRow(
        id: 'item-1',
        name: 'Nasi goreng',
        amount: 4500000,
        share: 0.52,
      ),
    ];

    final text = buildWhatsAppSummary(
      storeName: 'Warung Bu Sari',
      range: PeriodRange.containing(
        period: AnalyticsPeriod.bulan,
        date: DateTime(2026, 11, 15),
      ),
      summary: summary,
      masukRows: masukRows,
    );

    expect(
      text,
      'Warung Bu Sari · November 2026\n'
      'Masuk Rp 8.640.000 (+12%)\n'
      'Keluar Rp 5.210.000 (-5%)\n'
      'Untung Rp 3.430.000 (—)\n'
      'Ambil pribadi Rp 600.000\n'
      '10 dari 15 hari dicatat\n'
      'Piutang Rp 240.000 · Utang Rp 1.200.000\n'
      '\n'
      'Paling laku:\n'
      '- Nasi goreng Rp 4.500.000',
    );
  });
}
