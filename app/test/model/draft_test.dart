import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/draft.dart';
import 'package:malas/model/transaction.dart';

void main() {
  AiReadResult readMock() {
    return AiReadResult.fromJson(
      mockBodiesByRoute['POST /ai/read']! as Map<String, Object?>,
    );
  }

  test('parsesTheAiReadMockIntoThreeDrafts', () {
    final result = readMock();

    expect(result.drafts, hasLength(3));
    expect(result.drafts[1].direction, Direction.keluar);
    expect(result.drafts[0].lines[1].quantity, '25');
    expect(result.drafts[0].lines[1].lineTotal, isNull);
    expect(result.drafts[2].payments, isEmpty);
    expect(result.warnings.single.code, 'UNCLEAR_READ');
    expect(result.warnings.single.lineIndex, 1);
  });

  test('sendsNoBusinessDateForHariIni', () {
    final draft = readMock().drafts.first;

    expect(draft.toJson().containsKey('businessDate'), isFalse);

    draft.businessDate = '2026-11-10';
    expect(draft.toJson()['businessDate'], '2026-11-10');
  });

  test('dropsTheCategoryHintFromTheSaveBody', () {
    final line = DraftLine.fromJson(const {
      'itemId': null,
      'itemName': 'Gas',
      'categoryId': null,
      'categoryHint': 'Operasional',
      'quantity': null,
      'unit': null,
      'unitPrice': null,
      'lineTotal': 25000,
    });

    expect(line.toJson().containsKey('categoryHint'), isFalse);
  });

  test('recomputeTotalSumsKnownLinesAndKeepsAFullPaymentFull', () {
    final draft = readMock().drafts.first;

    draft.lines[1].lineTotal = 75000;
    draft.recomputeTotal();

    expect(draft.total, 255000);
    expect(draft.payments.single.amount, 255000);
  });

  test('recomputeTotalLeavesAnOpenBalanceOpen', () {
    final bon = readMock().drafts[2];

    bon.lines.single.lineTotal = 35000;
    bon.recomputeTotal();

    expect(bon.total, 35000);
    expect(bon.payments, isEmpty);
  });

  test('moveToDateCarriesTheSameDayPaymentAlong', () {
    final draft = readMock().drafts.first;

    draft.moveToDate(businessDate: '2026-11-10', businessToday: '2026-11-11');

    expect(draft.businessDate, '2026-11-10');
    expect(draft.payments.single.date, '2026-11-10');

    draft.moveToDate(businessDate: null, businessToday: '2026-11-11');

    expect(draft.businessDate, isNull);
    expect(draft.payments.single.date, '2026-11-11');
  });
}
