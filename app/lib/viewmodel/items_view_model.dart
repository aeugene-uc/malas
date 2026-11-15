import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/store_repository.dart';
import '../model/item.dart';

/// "Barang dan satuan" in Settings: rename an item, set its unit and price.
class ItemsViewModel extends ChangeNotifier {
  ItemsViewModel({required this._storeRepository});

  final StoreRepository _storeRepository;

  List<Item> _items = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Item> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _items = await _storeRepository.fetchItems();
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// [priceText] is what the owner typed, digits only or empty. Returns
  /// false with [errorMessage] when the server refused.
  Future<bool> saveItem({
    required Item item,
    required String name,
    required String? unit,
    required String priceText,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      _errorMessage = 'Nama barang wajib diisi';
      notifyListeners();
      return false;
    }
    final digits = priceText.replaceAll(RegExp(r'[^0-9]'), '');
    try {
      final savedItem = await _storeRepository.updateItem(
        itemId: item.id,
        name: trimmedName,
        unit: unit,
        savedPrice: digits.isEmpty ? null : int.parse(digits),
      );
      _items = [
        for (final existingItem in _items)
          existingItem.id == item.id ? savedItem : existingItem,
      ];
      _errorMessage = null;
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      notifyListeners();
    }
  }
}
