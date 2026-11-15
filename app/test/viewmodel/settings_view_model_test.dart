import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/store_repository.dart';
import 'package:malas/model/account.dart';
import 'package:malas/model/item.dart';
import 'package:malas/viewmodel/items_view_model.dart';
import 'package:malas/viewmodel/settings_view_model.dart';

import '../support/recording_adapter.dart';

void main() {
  late RecordingAdapter adapter;
  late ApiClient apiClient;

  final account = Account.fromJson(
    mockBodiesByRoute['GET /auth/me']! as Map<String, Object?>,
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = RecordingAdapter(bodiesByRoute: mockBodiesByRoute);
    apiClient = ApiClient(
      Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
    );
  });

  SettingsViewModel buildSettings() => SettingsViewModel(
    account: account,
    storeRepository: StoreRepository(apiClient),
  );

  test('startsFromTheStoresSavedSettingsWithNothingToSave', () {
    final settings = buildSettings();

    expect(settings.closedDays, {DateTime.sunday});
    expect(settings.reminderTime, '20:00');
    expect(settings.hasChanges, isFalse);
  });

  test('anEditThatIsUndoneLeavesNothingToSave', () {
    final settings = buildSettings();

    settings.toggleClosedDay(DateTime.friday);
    expect(settings.hasChanges, isTrue);
    settings.toggleClosedDay(DateTime.friday);

    expect(settings.hasChanges, isFalse);
  });

  test('turningTheReminderBackOnKeepsTheSavedTime', () {
    final settings = buildSettings();

    settings.setReminderOn(false);
    expect(settings.reminderTime, isNull);
    settings.setReminderOn(true);

    expect(settings.reminderTime, '20:00');
  });

  test('simpanSendsTheEditedSettingsAndReturnsTheAccount', () async {
    final settings = buildSettings();

    settings.toggleClosedDay(DateTime.friday);
    settings.selectDayChangeHour(3);
    settings.setReminderOn(false);
    settings.setAlertsOn(false);
    final savedAccount = await settings.save();

    final patch = adapter.requests.firstWhere((r) => r.method == 'PATCH');
    expect(patch.data, {
      'businessTypes': ['MAKANAN_MINUMAN'],
      'closedDays': [5, 7],
      'dayChangeHour': 3,
      'reminderTime': null,
      'alertsOn': false,
    });
    expect(savedAccount!.store.closedDays, {DateTime.friday, DateTime.sunday});
    expect(savedAccount.store.dayChangeHour, 3);
    expect(savedAccount.store.reminderTime, isNull);
    expect(savedAccount.store.isAlertsOn, isFalse);
  });

  test('simpanKeepsTheNewReminderTimeForTheReminder', () async {
    final settings = buildSettings();

    settings.selectReminderTime('19:45');
    final savedAccount = await settings.save();

    expect(savedAccount!.store.reminderTime, '19:45');
    expect(savedAccount.store.name, 'Warung Bu Sari');
  });

  test('needsAtLeastOneJenisUsaha', () async {
    final settings = buildSettings();

    settings.toggleBusinessType(BusinessType.makananMinuman);
    final savedAccount = await settings.save();

    expect(savedAccount, isNull);
    expect(settings.errorMessage, 'Pilih jenis usaha');
    expect(adapter.requests, isEmpty);
  });

  group('items', () {
    ItemsViewModel buildItems() =>
        ItemsViewModel(storeRepository: StoreRepository(apiClient));

    test('savesThePriceAsTypedWithThousandsDots', () async {
      final items = buildItems();
      await items.load();

      final isSaved = await items.saveItem(
        item: items.items[1],
        name: ' Es teh manis ',
        unit: 'pcs',
        priceText: '4.000',
      );

      expect(isSaved, isTrue);
      expect(adapter.lastRequest.data, {
        'name': 'Es teh manis',
        'unit': 'pcs',
        'savedPrice': 4000,
      });
      expect(items.items[1].name, 'Es teh manis');
    });

    test('editingOneItemLeavesTheOthersAsTheyWere', () async {
      final items = buildItems();
      await items.load();
      final gas = items.items.last;

      await items.saveItem(
        item: gas,
        name: 'Gas 3 kg',
        unit: 'pcs',
        priceText: '22000',
      );

      expect(items.items.map((item) => item.name), [
        'Nasi goreng',
        'Es teh',
        'Gas 3 kg',
      ]);
      expect(items.items.last.kind, ItemKind.dibeli);
      expect(items.items.last.savedPrice, 22000);
      expect(items.items[1].savedPrice, 3000);
    });

    test('anEmptyPriceClearsIt', () async {
      final items = buildItems();
      await items.load();

      await items.saveItem(
        item: items.items.last,
        name: 'Gas',
        unit: null,
        priceText: '',
      );

      expect(
        (adapter.lastRequest.data as Map<String, Object?>)['savedPrice'],
        isNull,
      );
    });

    test('anItemNeedsAName', () async {
      final items = buildItems();
      await items.load();
      final requestCount = adapter.requests.length;

      final isSaved = await items.saveItem(
        item: items.items.first,
        name: ' ',
        unit: 'porsi',
        priceText: '15000',
      );

      expect(isSaved, isFalse);
      expect(items.errorMessage, 'Nama barang wajib diisi');
      expect(adapter.requests, hasLength(requestCount));
    });

    test('groupsItemsByWhetherTheyAreSoldOrBought', () async {
      final items = buildItems();
      await items.load();

      expect(
        items.items.where((item) => item.kind == ItemKind.dibeli).single.name,
        'Gas',
      );
    });
  });
}
