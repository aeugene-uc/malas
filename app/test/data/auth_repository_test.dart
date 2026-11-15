import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/auth_repository.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/account.dart';

import '../support/recording_adapter.dart';

void main() {
  late RecordingAdapter adapter;
  late FlutterSecureStorage secureStorage;
  late AuthRepository repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    secureStorage = const FlutterSecureStorage();
    adapter = RecordingAdapter(bodiesByRoute: mockBodiesByRoute);
    final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
      ..httpClientAdapter = adapter;
    repository = AuthRepository(
      apiClient: ApiClient(dio),
      secureStorage: secureStorage,
    );
  });

  test('signInKeepsTheTokenAndSendsItOnLaterRequests', () async {
    await repository.signIn(phone: '0812 3456 7890', password: 'rahasia');

    expect(adapter.lastRequest.data, {
      'phone': '0812 3456 7890',
      'password': 'rahasia',
    });
    expect(await secureStorage.read(key: AuthRepository.tokenKey), isNotNull);

    await repository.fetchAccount();

    expect(adapter.lastRequest.headers['Authorization'], 'Bearer mock-token');
  });

  test('restoresNoSessionWithoutASavedToken', () async {
    expect(await repository.restoreSession(), isNull);
  });

  test('restoresTheSessionFromASavedToken', () async {
    await secureStorage.write(key: AuthRepository.tokenKey, value: 'saved');

    final account = await repository.restoreSession();

    expect(adapter.lastRequest.headers['Authorization'], 'Bearer saved');
    expect(account!.isSetUp, isTrue);
  });

  test('aNewRegistrationStillNeedsFirstRunSetup', () async {
    final account = await repository.register(
      name: 'Pak Budi',
      phone: '081298765432',
      password: 'rahasia',
    );

    expect(account.isSetUp, isFalse);
  });

  test('signOutForgetsTheToken', () async {
    await repository.signIn(phone: '0812', password: 'rahasia');

    await repository.signOut();

    expect(await secureStorage.read(key: AuthRepository.tokenKey), isNull);
  });

  test('savesTheStoreSetupInWireValues', () async {
    await repository.saveStoreSetup(
      storeId: 'store-2',
      storeName: 'Warung Pak Budi',
      businessTypes: {BusinessType.makananMinuman, BusinessType.jasa},
    );

    expect(adapter.lastRequest.method, 'PATCH');
    expect(adapter.lastRequest.path, '/stores/store-2');
    expect(adapter.lastRequest.data, {
      'name': 'Warung Pak Budi',
      'businessTypes': ['MAKANAN_MINUMAN', 'JASA'],
    });
  });

  test('remembersThatTheTrialSheetWasShown', () async {
    expect(await repository.hasSeenTrialSheet(), isFalse);

    await repository.markTrialSheetSeen();

    expect(await repository.hasSeenTrialSheet(), isTrue);
  });
}
