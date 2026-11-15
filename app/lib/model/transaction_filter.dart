import 'transaction.dart';

/// What Catatan shows (§6): masuk or keluar, belum lunas, a search, and one
/// item, category or person when opened from an Analisis row.
class TransactionFilter {
  const TransactionFilter({
    this.direction,
    this.isUnpaidOnly = false,
    this.query = '',
    this.focus,
  });

  final Direction? direction;
  final bool isUnpaidOnly;
  final String query;
  final FilterFocus? focus;

  TransactionFilter copyWith({
    Direction? Function()? direction,
    bool? isUnpaidOnly,
    String? query,
    FilterFocus? Function()? focus,
  }) {
    return TransactionFilter(
      direction: direction == null ? this.direction : direction(),
      isUnpaidOnly: isUnpaidOnly ?? this.isUnpaidOnly,
      query: query ?? this.query,
      focus: focus == null ? this.focus : focus(),
    );
  }

  /// The `GET /transactions` query, leaving out what is not set.
  Map<String, Object?> toQuery() {
    final trimmedQuery = query.trim();
    return {
      'direction': ?direction?.wireValue,
      if (isUnpaidOnly) 'unpaid': 'true',
      if (trimmedQuery.isNotEmpty) 'q': trimmedQuery,
      if (focus case final focus?) focus.kind.queryKey: focus.id,
    };
  }
}

/// One item, category or person that Catatan is narrowed to.
class FilterFocus {
  const FilterFocus({required this.kind, required this.id, required this.name});

  final FocusKind kind;
  final String id;

  /// Shown on the chip that clears it.
  final String name;
}

enum FocusKind {
  item('itemId'),
  category('categoryId'),
  person('personId');

  const FocusKind(this.queryKey);

  final String queryKey;
}
