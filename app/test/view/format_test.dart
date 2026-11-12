import 'package:flutter_test/flutter_test.dart';
import 'package:malas/view/format.dart';

void main() {
  group('formatRupiah', () {
    test('putsADotBetweenThousands', () {
      expect(formatRupiah(1200000), 'Rp 1.200.000');
      expect(formatRupiah(12500), 'Rp 12.500');
      expect(formatRupiah(240000), 'Rp 240.000');
    });

    test('leavesAmountsUnderAThousandUngrouped', () {
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(500), 'Rp 500');
    });

    test('putsTheMinusBeforeRp', () {
      expect(formatRupiah(-60000), '-Rp 60.000');
    });
  });

  test('formatWeekdayShortGivesTheIndonesianDay', () {
    expect(formatWeekdayShort('2026-11-09'), 'Sen');
    expect(formatWeekdayShort('2026-11-10'), 'Sel');
    expect(formatWeekdayShort('2026-11-15'), 'Min');
  });
}
