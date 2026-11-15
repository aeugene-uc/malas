import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/tanya_answer.dart';
import 'package:malas/view/tanya/tanya_text.dart';

void main() {
  test('fillsEachPlaceholderWithTheFigureCodeComputed', () {
    final answer = TanyaAnswer.fromJson(
      mockBodiesByRoute['POST /ai/ask']! as Map<String, Object?>,
    );

    expect(
      fillAnswer(answer),
      'Paling laku minggu ini: 42 porsi (Rp 630.000) dan 30 gelas (Rp 90.000).',
    );
    expect(answer.daysRecorded, 5);
    expect(answer.periodFrom, '2026-11-09');
  });

  test('neverInventsANumberForAPlaceholderWithoutAFigure', () {
    const answer = TanyaAnswer(
      answer: 'Untung {f0}, naik {f9}.',
      figures: [
        TanyaFigure(key: 'f0', label: 'Untung', value: 1500000, unit: 'IDR'),
      ],
      daysRecorded: null,
      periodFrom: null,
      periodTo: null,
    );

    expect(fillAnswer(answer), 'Untung Rp 1.500.000, naik —.');
  });

  test('showsAFractionalQuantityWithADecimalComma', () {
    const halfKilo = TanyaFigure(
      key: 'f0',
      label: 'Gula',
      value: 0.5,
      unit: 'kg',
    );

    expect(formatFigure(halfKilo), '0,5 kg');
  });

  test('anAnswerWithNoDataHasNoFigures', () {
    final answer = TanyaAnswer.fromJson({
      'answer': 'Datanya belum ada',
      'figures': <Object>[],
    });

    expect(fillAnswer(answer), 'Datanya belum ada');
    expect(answer.daysRecorded, isNull);
  });
}
