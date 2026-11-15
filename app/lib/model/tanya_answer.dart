/// The reply of `POST /ai/ask` (Multiplayr #59). The model writes [answer]
/// with `{f0}`-style placeholders, and code fills them from [figures], so
/// every number shown comes from code, not from the model (§7.8).
class TanyaAnswer {
  const TanyaAnswer({
    required this.answer,
    required this.figures,
    required this.daysRecorded,
    required this.periodFrom,
    required this.periodTo,
  });

  factory TanyaAnswer.fromJson(Map<String, Object?> json) {
    final figuresJson = json['figures'] as List<Object?>;
    final periodJson = json['period'] as Map<String, Object?>?;
    return TanyaAnswer(
      answer: json['answer'] as String,
      figures: [
        for (final figureJson in figuresJson)
          TanyaFigure.fromJson(figureJson as Map<String, Object?>),
      ],
      daysRecorded: json['daysRecorded'] as int?,
      periodFrom: periodJson?['from'] as String?,
      periodTo: periodJson?['to'] as String?,
    );
  }

  /// "Datanya belum ada" with no figures when the data can't answer.
  final String answer;
  final List<TanyaFigure> figures;
  final int? daysRecorded;

  /// `"YYYY-MM-DD"`, the dates the figures cover.
  final String? periodFrom;
  final String? periodTo;
}

class TanyaFigure {
  const TanyaFigure({
    required this.key,
    required this.label,
    required this.value,
    required this.unit,
  });

  factory TanyaFigure.fromJson(Map<String, Object?> json) {
    return TanyaFigure(
      key: json['key'] as String,
      label: json['label'] as String,
      value: json['value'] as num,
      unit: json['unit'] as String,
    );
  }

  /// The placeholder name in the answer, `f0` for `{f0}`.
  final String key;
  final String label;
  final num value;

  /// `IDR` for money in integer rupiah, otherwise a quantity's unit.
  final String unit;

  bool get isMoney => unit == 'IDR';
}
