import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/store_repository.dart';
import 'package:malas/model/transaction.dart';

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
}
