import 'transaction.dart';

/// A money category (spec §4.2): the 14 fixed ones every store starts with,
/// plus any the owner adds.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.direction,
    required this.isCountedInProfit,
    required this.isFixed,
  });

  factory Category.fromJson(Map<String, Object?> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      direction: Direction.fromWire(json['direction'] as String),
      isCountedInProfit: json['countedInProfit'] as bool,
      isFixed: json['fixed'] as bool,
    );
  }

  final String id;
  final String name;
  final Direction direction;
  final bool isCountedInProfit;
  final bool isFixed;
}
