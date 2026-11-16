import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../model/account.dart';
import '../model/category.dart';
import '../model/item.dart';
import 'api_client.dart';

/// Settings (§6): the store's own fields, its items and its categories.
class StoreRepository {
  /// Without [secureStorage] nothing is kept on the phone.
  StoreRepository(this._apiClient, {this._secureStorage});

  /// Signing out deletes it, so the next account on the phone never offers
  /// this store's categories.
  static const String keptCategoriesKey = 'categories';

  final ApiClient _apiClient;
  final FlutterSecureStorage? _secureStorage;

  /// [reminderTime] null turns the evening reminder off.
  Future<void> saveSettings({
    required String storeId,
    required Set<BusinessType> businessTypes,
    required Set<int> closedDays,
    required int dayChangeHour,
    required String? reminderTime,
    required bool isAlertsOn,
  }) async {
    await _apiClient.patch(
      '/stores/$storeId',
      body: {
        'businessTypes': [for (final type in businessTypes) type.wireValue],
        'closedDays': [...closedDays]..sort(),
        'dayChangeHour': dayChangeHour,
        'reminderTime': reminderTime,
        'alertsOn': isAlertsOn,
      },
    );
  }

  Future<List<Item>> fetchItems() async {
    final body = await _apiClient.get('/items') as Map<String, Object?>;
    final itemsJson = body['items'] as List<Object?>;
    return [
      for (final itemJson in itemsJson)
        Item.fromJson(itemJson as Map<String, Object?>),
    ];
  }

  /// Without signal it answers with the categories last fetched on this
  /// phone, so Ketik still records an amount offline (§12) and a failed save
  /// is kept for Coba lagi (#25).
  Future<List<Category>> fetchCategories() async {
    final List<Object?> categoriesJson;
    try {
      final body = await _apiClient.get('/categories') as Map<String, Object?>;
      categoriesJson = body['categories'] as List<Object?>;
    } on ApiException catch (error) {
      final kept = error.isNetworkError
          ? await _secureStorage?.read(key: keptCategoriesKey)
          : null;
      if (kept == null) rethrow;
      return _readCategories(jsonDecode(kept) as List<Object?>);
    }
    await _secureStorage?.write(
      key: keptCategoriesKey,
      value: jsonEncode(categoriesJson),
    );
    return _readCategories(categoriesJson);
  }

  Future<void> updateItem({
    required String itemId,
    required String name,
    required String? unit,
    required int? savedPrice,
  }) async {
    await _apiClient.patch(
      '/items/$itemId',
      body: {'name': name, 'unit': unit, 'savedPrice': savedPrice},
    );
  }
}

List<Category> _readCategories(List<Object?> categoriesJson) {
  return [
    for (final categoryJson in categoriesJson)
      Category.fromJson(categoryJson as Map<String, Object?>),
  ];
}
