import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/analytics.dart';

void main() {
  // Sunday 15 Nov 2026.
  final sunday = DateTime(2026, 11, 15, 22, 30);

  group('PeriodRange', () {
    test('aWeekRunsMondayToSundayEvenOnASunday', () {
      final week = PeriodRange.containing(
        period: AnalyticsPeriod.minggu,
        date: sunday,
      );

      expect(week.from, DateTime.utc(2026, 11, 9));
      expect(week.to, DateTime.utc(2026, 11, 15));
      expect(week.fromWire, '2026-11-09');
    });

    test('aMonthEndsOnItsLastDay', () {
      final month = PeriodRange.containing(
        period: AnalyticsPeriod.bulan,
        date: DateTime(2026, 2, 10),
      );

      expect(month.from, DateTime.utc(2026, 2, 1));
      expect(month.to, DateTime.utc(2026, 2, 28));
    });

    test('previousAndNextStepAcrossAYearEnd', () {
      final january = PeriodRange.containing(
        period: AnalyticsPeriod.bulan,
        date: DateTime(2027, 1, 20),
      );

      expect(january.previous.from, DateTime.utc(2026, 12, 1));
      expect(january.previous.next.from, january.from);
    });

    test('aYearRunsJanuaryToDecember', () {
      final year = PeriodRange.containing(
        period: AnalyticsPeriod.tahun,
        date: sunday,
      );

      expect(year.fromWire, '2026-01-01');
      expect(year.to, DateTime.utc(2026, 12, 31));
      expect(year.contains(DateTime(2026, 12, 31, 23)), isTrue);
      expect(year.contains(DateTime(2027, 1, 1)), isFalse);
    });
  });

  test('readsTheSummaryWithANullChangeForAZeroPreviousPeriod', () {
    final summary = AnalyticsSummary.fromJson(
      mockBodiesByRoute['GET /analytics/summary']! as Map<String, Object?>,
    );

    expect(summary.untung, 3430000);
    expect(summary.changes.masuk, 0.12);
    expect(summary.changes.untung, isNull);
    expect(summary.notCountedInProfit.ambilPribadi, 600000);
    expect(summary.notCountedInProfit.isEmpty, isFalse);
  });
}
