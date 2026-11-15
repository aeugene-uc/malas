import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/store_repository.dart';
import 'package:malas/model/account.dart';
import 'package:malas/model/item.dart';

import '../support/recording_adapter.dart';

void main() {
  late RecordingAdapter adapter;
  late StoreRepository repository;

  setUp(() {
    adapter = RecordingAdapter(bodiesByRoute: mockBodiesByRoute);
    final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
      ..httpClientAdapter = adapter;
    repository = StoreRepository(ApiClient(dio));
  });

  test('savesEverySettingWithClosedDaysInWeekOrder', () async {
    await repository.saveSettings(
      storeId: 'store-1',
      businessTypes: {BusinessType.jasa},
      closedDays: {DateTime.sunday, DateTime.monday},
      dayChangeHour: 5,
      reminderTime: '21:30',
      isAlertsOn: false,
    );

    expect(adapter.lastRequest.method, 'PATCH');
    expect(adapter.lastRequest.path, '/stores/store-1');
    expect(adapter.lastRequest.data, {
      'businessTypes': ['JASA'],
      'closedDays': [1, 7],
      'dayChangeHour': 5,
      'reminderTime': '21:30',
      'alertsOn': false,
    });
  });

  test('sendsANullReminderTimeToTurnTheReminderOff', () async {
    await repository.saveSettings(
      storeId: 'store-1',
      businessTypes: {BusinessType.jasa},
      closedDays: {},
      dayChangeHour: 4,
      reminderTime: null,
      isAlertsOn: true,
    );

    final body = adapter.lastRequest.data as Map<String, Object?>;
    expect(body.containsKey('reminderTime'), isTrue);
    expect(body['reminderTime'], isNull);
  });

  test('readsItemsWithTheirKindUnitAndPrice', () async {
    final items = await repository.fetchItems();

    expect(items.map((item) => item.name), ['Nasi goreng', 'Es teh', 'Gas']);
    expect(items.first.unit, 'porsi');
    expect(items.last.kind, ItemKind.dibeli);
    expect(items.last.savedPrice, isNull);
  });

  test('sendsTheItemsNewNameUnitAndPrice', () async {
    await repository.updateItem(
      itemId: 'item-2',
      name: 'Es teh manis',
      unit: 'pcs',
      savedPrice: 4000,
    );

    expect(adapter.lastRequest.path, '/items/item-2');
    expect(adapter.lastRequest.data, {
      'name': 'Es teh manis',
      'unit': 'pcs',
      'savedPrice': 4000,
    });
  });
}
