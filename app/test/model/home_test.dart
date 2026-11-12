import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/home.dart';
import 'package:malas/model/transaction.dart';

void main() {
  test('parsesTheHomeMockBody', () {
    final home = Home.fromJson(
      mockBodiesByRoute['GET /home']! as Map<String, Object?>,
    );

    expect(home.today.masuk, 420000);
    expect(home.today.keluar, 150000);
    expect(home.comparisons.map((comparison) => comparison.label), [
      'Kemarin',
      'Selasa lalu',
    ]);
    expect(home.cards.alerts.single.rule, 'PRICE_RISE');
    expect(home.cards.missedDays, ['2026-11-09']);
    expect(home.cards.piutang, 240000);
    expect(home.entries.single.direction, Direction.masuk);
    expect(home.entries.single.lines.first.quantity, '2');
  });

  test('readsALeftOutCardAsAbsent', () {
    final cards = HomeCards.fromJson(const {'utang': 1200000});

    expect(cards.alerts, isEmpty);
    expect(cards.missedDays, isEmpty);
    expect(cards.piutang, isNull);
    expect(cards.dueToday, isNull);
    expect(cards.hasOpenBalances, isTrue);
  });

  test('rejectsAnUnknownDirection', () {
    expect(() => Direction.fromWire('SIDEWAYS'), throwsFormatException);
  });

  test('countsAnOverpaidTransactionAsFullyPaid', () {
    final transaction = Transaction.fromJson(const {
      'id': 'trx-1',
      'businessDate': '2026-11-11',
      'direction': 'IN',
      'total': 30000,
      'paid': 35000,
      'remaining': -5000,
      'editCount': 0,
      'hasRetur': false,
      'person': null,
      'lines': <Object?>[],
    });

    expect(transaction.isFullyPaid, isTrue);
  });
}
