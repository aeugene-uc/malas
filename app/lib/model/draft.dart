import 'transaction.dart';

/// What `POST /ai/read` returns: one voice note can hold several
/// transactions, so it comes back as several drafts.
class AiReadResult {
  const AiReadResult({
    required this.inputId,
    required this.drafts,
    required this.warnings,
  });

  factory AiReadResult.fromJson(Map<String, Object?> json) {
    final draftsJson = json['drafts'] as List<Object?>;
    final warningsJson = json['warnings'] as List<Object?>? ?? const [];
    return AiReadResult(
      inputId: json['inputId'] as String?,
      drafts: [
        for (final draftJson in draftsJson)
          Draft.fromJson(draftJson as Map<String, Object?>),
      ],
      warnings: [
        for (final warningJson in warningsJson)
          ReadWarning.fromJson(warningJson as Map<String, Object?>),
      ],
    );
  }

  final String? inputId;
  final List<Draft> drafts;
  final List<ReadWarning> warnings;
}

/// A flag on a draft or one of its lines. It never blocks Simpan (§5.4).
class ReadWarning {
  const ReadWarning({
    required this.code,
    required this.message,
    required this.draftIndex,
    required this.lineIndex,
  });

  factory ReadWarning.fromJson(Map<String, Object?> json) {
    return ReadWarning(
      code: json['code'] as String,
      message: json['message'] as String,
      draftIndex: json['draftIndex'] as int,
      lineIndex: json['lineIndex'] as int?,
    );
  }

  final String code;

  /// Written by the server in Indonesian; the chip shows it as it is.
  final String message;
  final int draftIndex;

  /// Null when the warning is about the whole draft.
  final int? lineIndex;
}

/// One transaction the owner is checking before Simpan. It is the
/// `POST /transactions` body, and the owner's edits change it in place.
class Draft {
  Draft({
    required this.businessDate,
    required this.direction,
    required this.total,
    required this.personId,
    required this.personName,
    required this.dueDate,
    required this.source,
    required this.inputId,
    required this.note,
    required this.lines,
    required this.payments,
  });

  factory Draft.fromJson(Map<String, Object?> json) {
    final linesJson = json['lines'] as List<Object?>;
    final paymentsJson = json['payments'] as List<Object?>;
    return Draft(
      businessDate: json['businessDate'] as String?,
      direction: Direction.fromWire(json['direction'] as String),
      total: json['total'] as int,
      personId: json['personId'] as String?,
      personName: json['personName'] as String?,
      dueDate: json['dueDate'] as String?,
      source: json['source'] as String,
      inputId: json['inputId'] as String?,
      note: json['note'] as String?,
      lines: [
        for (final lineJson in linesJson)
          DraftLine.fromJson(lineJson as Map<String, Object?>),
      ],
      payments: [
        for (final paymentJson in paymentsJson)
          DraftPayment.fromJson(paymentJson as Map<String, Object?>),
      ],
    );
  }

  /// Null means Hari ini: the server resolves today from the store's
  /// timezone and day-change hour, so the app sends no date at all.
  String? businessDate;
  Direction direction;
  int total;
  String? personId;
  String? personName;
  String? dueDate;
  String source;
  String? inputId;
  String? note;
  final List<DraftLine> lines;
  final List<DraftPayment> payments;

  /// Moves the draft to another day. A payment made on the draft's old day
  /// moves with it, since "paid in full" means paid on the sale's own day.
  void moveToDate({
    required String? businessDate,
    required String businessToday,
  }) {
    final oldDay = this.businessDate ?? businessToday;
    final newDay = businessDate ?? businessToday;
    for (final payment in payments) {
      if (payment.date == oldDay) payment.date = newDay;
    }
    this.businessDate = businessDate;
  }

  /// Keeps the provisional total in step after the owner edits a line, by
  /// the backend's draft rule: the sum of the line totals that are known.
  /// The server recomputes everything on Simpan; this is only what the owner
  /// sees meanwhile. A draft paid in full stays paid in full.
  void recomputeTotal() {
    final isPaidInFull =
        payments.length == 1 && payments.single.amount == total;
    total = lines.fold(0, (sum, line) => sum + (line.lineTotal ?? 0));
    if (isPaidInFull) payments.single.amount = total;
  }

  Map<String, Object?> toJson() {
    return {
      'businessDate': ?businessDate,
      'direction': direction.wireValue,
      'total': total,
      'personId': personId,
      'personName': personName,
      'dueDate': dueDate,
      'source': source,
      'inputId': inputId,
      'note': note,
      'lines': [for (final line in lines) line.toJson()],
      'payments': [for (final payment in payments) payment.toJson()],
    };
  }
}

class DraftLine {
  DraftLine({
    required this.itemId,
    required this.itemName,
    required this.categoryId,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.lineTotal,
  });

  /// `categoryHint` is the model's guess and is not read: the server picks
  /// the category from the fixed list.
  factory DraftLine.fromJson(Map<String, Object?> json) {
    return DraftLine(
      itemId: json['itemId'] as String?,
      itemName: json['itemName'] as String?,
      categoryId: json['categoryId'] as String?,
      quantity: json['quantity'] as String?,
      unit: json['unit'] as String?,
      unitPrice: json['unitPrice'] as int?,
      lineTotal: json['lineTotal'] as int?,
    );
  }

  String? itemId;
  String? itemName;
  String? categoryId;

  /// A decimal string such as "0.5", or null on a bare amount.
  String? quantity;
  String? unit;
  int? unitPrice;

  /// Null when no price is known yet. The line still saves, flagged (§5.4).
  int? lineTotal;

  Map<String, Object?> toJson() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'categoryId': categoryId,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'lineTotal': lineTotal,
    };
  }
}

class DraftPayment {
  DraftPayment({required this.date, required this.amount, required this.label});

  factory DraftPayment.fromJson(Map<String, Object?> json) {
    return DraftPayment(
      date: json['date'] as String,
      amount: json['amount'] as int,
      label: json['label'] as String?,
    );
  }

  String date;
  int amount;

  /// cash, QRIS, transfer and so on.
  String? label;

  Map<String, Object?> toJson() {
    return {'date': date, 'amount': amount, 'label': label};
  }
}
