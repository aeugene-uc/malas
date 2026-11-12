/// Money in (Masuk) or money out (Keluar).
enum Direction {
  masuk('IN'),
  keluar('OUT');

  const Direction(this.wireValue);

  /// How the backend writes it.
  final String wireValue;

  static Direction fromWire(String wireValue) {
    return Direction.values.firstWhere(
      (direction) => direction.wireValue == wireValue,
      orElse: () => throw FormatException('Unknown direction: $wireValue'),
    );
  }
}

/// An item, category or person as list responses embed it: id and name.
class NamedRef {
  const NamedRef({required this.id, required this.name});

  factory NamedRef.fromJson(Map<String, Object?> json) {
    return NamedRef(id: json['id'] as String, name: json['name'] as String);
  }

  final String id;
  final String name;
}

/// A saved transaction as list and detail responses send it. `paid` and
/// `remaining` come from the server, so the app never adds up payments.
class Transaction {
  const Transaction({
    required this.id,
    required this.businessDate,
    required this.direction,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.editCount,
    required this.hasRetur,
    required this.person,
    required this.lines,
  });

  factory Transaction.fromJson(Map<String, Object?> json) {
    final personJson = json['person'] as Map<String, Object?>?;
    final linesJson = json['lines'] as List<Object?>;
    return Transaction(
      id: json['id'] as String,
      businessDate: json['businessDate'] as String,
      direction: Direction.fromWire(json['direction'] as String),
      total: json['total'] as int,
      paid: json['paid'] as int,
      remaining: json['remaining'] as int,
      editCount: json['editCount'] as int,
      hasRetur: json['hasRetur'] as bool,
      person: personJson == null ? null : NamedRef.fromJson(personJson),
      lines: [
        for (final lineJson in linesJson)
          TransactionLine.fromJson(lineJson as Map<String, Object?>),
      ],
    );
  }

  final String id;

  /// `YYYY-MM-DD`, kept as text so no time zone can move it.
  final String businessDate;
  final Direction direction;
  final int total;
  final int paid;

  /// Negative when overpaid: the extra is owed back (Kembalikan).
  final int remaining;
  final int editCount;
  final bool hasRetur;
  final NamedRef? person;
  final List<TransactionLine> lines;

  bool get isFullyPaid => remaining <= 0;
}

class TransactionLine {
  const TransactionLine({
    required this.id,
    required this.item,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.lineTotal,
    required this.discount,
  });

  factory TransactionLine.fromJson(Map<String, Object?> json) {
    final itemJson = json['item'] as Map<String, Object?>?;
    final categoryJson = json['category'] as Map<String, Object?>?;
    return TransactionLine(
      id: json['id'] as String,
      item: itemJson == null ? null : NamedRef.fromJson(itemJson),
      category: categoryJson == null ? null : NamedRef.fromJson(categoryJson),
      quantity: json['quantity'] as String?,
      unit: json['unit'] as String?,
      unitPrice: json['unitPrice'] as int?,
      lineTotal: json['lineTotal'] as int,
      discount: json['discount'] as int,
    );
  }

  final String id;

  /// Null on a bare amount ("Omzet hari ini 1,2 juta").
  final NamedRef? item;
  final NamedRef? category;

  /// A decimal string such as "0.5", never a double, so it can't round.
  final String? quantity;
  final String? unit;
  final int? unitPrice;
  final int lineTotal;
  final int discount;
}
