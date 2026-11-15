import '../model/account.dart';
import '../model/item.dart';
import 'api_client.dart';

/// Settings (§6): the store's own fields and its items.
class StoreRepository {
  StoreRepository(this._apiClient);

  final ApiClient _apiClient;

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
