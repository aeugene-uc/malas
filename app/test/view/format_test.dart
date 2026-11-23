import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/model/transaction.dart';
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

  group('formatEntryTotal', () {
    Transaction entry(String direction, int total) => Transaction.fromJson({
      'id': 't',
      'businessDate': '2026-11-23',
      'direction': direction,
      'total': total,
      'paid': total,
      'remaining': 0,
      'editCount': 0,
      'hasRetur': false,
      'lines': <Object>[],
    });

    test('signsAnEntryByWhatItDidToTheMoney', () {
      expect(formatEntryTotal(entry('IN', 50000)), '+Rp 50.000');
      expect(formatEntryTotal(entry('OUT', 50000)), '-Rp 50.000');
    });

    test('turnsTheSignForAReturWithOneMinusOnly', () {
      expect(formatEntryTotal(entry('OUT', -50000)), '+Rp 50.000');
      expect(formatEntryTotal(entry('IN', -50000)), '-Rp 50.000');
    });
  });

  group('RupiahInputFormatter', () {
    TextEditingValue typed(String text, {int? cursor}) {
      return RupiahInputFormatter().formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: cursor ?? text.length),
        ),
      );
    }

    test('putsTheDotsInAsTheOwnerTypes', () {
      expect(typed('1200000').text, '1.200.000');
      expect(typed('1200000').selection.end, 9);
      expect(typed('1.200.0005').text, '12.000.005');
      expect(typed('500').text, '500');
      expect(typed('').text, '');
    });

    test('keepsTheCursorAfterTheSameDigit', () {
      // A 5 typed after the 1 of "1.200".
      final value = typed('15.200', cursor: 2);

      expect(value.text, '15.200');
      expect(value.selection.end, 2);

      // A 9 typed after "99" of "999" grows a dot before the cursor.
      final grown = typed('9999', cursor: 3);

      expect(grown.text, '9.999');
      expect(grown.selection.end, 4);
    });
  });

  test('formatWeekdayShortGivesTheIndonesianDay', () {
    expect(formatWeekdayShort('2026-11-09'), 'Sen');
    expect(formatWeekdayShort('2026-11-10'), 'Sel');
    expect(formatWeekdayShort('2026-11-15'), 'Min');
  });
}
