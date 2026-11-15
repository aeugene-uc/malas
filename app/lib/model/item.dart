/// A thing sold or bought repeatedly, with a saved price and a unit (§4.1).
class Item {
  const Item({
    required this.id,
    required this.name,
    required this.kind,
    required this.unit,
    required this.savedPrice,
  });

  factory Item.fromJson(Map<String, Object?> json) {
    return Item(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: ItemKind.fromWire(json['kind'] as String),
      unit: json['unit'] as String?,
      savedPrice: json['savedPrice'] as int?,
    );
  }

  final String id;
  final String name;
  final ItemKind kind;
  final String? unit;

  /// The last price used, in rupiah. Null saves flagged "harga belum ada".
  final int? savedPrice;
}

enum ItemKind {
  dijual('SOLD', 'Dijual'),
  dibeli('BOUGHT', 'Dibeli');

  const ItemKind(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ItemKind fromWire(String wireValue) {
    return values.firstWhere(
      (kind) => kind.wireValue == wireValue,
      orElse: () => throw FormatException('Unknown item kind: $wireValue'),
    );
  }
}

/// The fixed unit list of §4.1.
const List<String> units = [
  'porsi',
  'pcs',
  'kg',
  'liter',
  'lembar',
  'jam',
  'malam',
  'bulan',
  'paket',
];
