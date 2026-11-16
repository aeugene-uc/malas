import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/store_repository.dart';
import 'package:malas/model/transaction.dart';

import '../support/signal_adapter.dart';
import '../support/status_adapter.dart';

void main() {
  test('fetchCategoriesReadsTheFourteenFixedCategories', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
      ..httpClientAdapter = MockApiAdapter(bodiesByRoute: mockBodiesByRoute);

    final categories = await StoreRepository(ApiClient(dio)).fetchCategories();

    expect(categories, hasLength(14));
    final penjualan = categories.firstWhere((c) => c.name == 'Penjualan');
    expect(penjualan.direction, Direction.masuk);
    expect(penjualan.isCountedInProfit, isTrue);
    final ambilPribadi = categories.firstWhere(
      (c) => c.name == 'Ambil pribadi',
    );
    expect(ambilPribadi.direction, Direction.keluar);
    expect(ambilPribadi.isCountedInProfit, isFalse);
  });

  group('kept on the phone for Ketik without signal (Q1 bug 2)', () {
    late SignalAdapter adapter;
    late StoreRepository repository;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      adapter = SignalAdapter();
      repository = StoreRepository(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
        ),
        secureStorage: const FlutterSecureStorage(),
      );
    });

    test('withoutSignalAnswersWithTheCategoriesLastFetched', () async {
      await repository.fetchCategories();
      adapter.isOffline = true;

      final categories = await repository.fetchCategories();

      expect(categories, hasLength(14));
      final penjualan = categories.firstWhere((c) => c.name == 'Penjualan');
      expect(penjualan.id, 'cat-1');
      expect(penjualan.direction, Direction.masuk);
    });

    test('withoutSignalOrAKeptListTheOfflineErrorReachesKetik', () async {
      adapter.isOffline = true;

      await expectLater(
        repository.fetchCategories(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.isNetworkError,
            'network',
            isTrue,
          ),
        ),
      );
    });

    test('aServerErrorIsNotHiddenBehindTheKeptList', () async {
      await repository.fetchCategories();
      adapter.answering = StatusAdapter(500);

      await expectLater(
        repository.fetchCategories(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 500)),
      );
    });
  });
}
