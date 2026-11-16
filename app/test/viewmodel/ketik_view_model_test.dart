import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/draft_repository.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/store_repository.dart';
import 'package:malas/data/unsent_drafts_store.dart';
import 'package:malas/model/transaction.dart';
import 'package:malas/viewmodel/ketik_view_model.dart';

void main() {
  late _KeyRecordingAdapter adapter;
  late KetikViewModel viewModel;

  setUp(() async {
    adapter = _KeyRecordingAdapter();
    final apiClient = ApiClient(
      Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
    );
    viewModel = KetikViewModel(
      storeRepository: StoreRepository(apiClient),
      draftRepository: DraftRepository(apiClient),
      businessToday: '2026-11-16',
    );
    await viewModel.loadCategories();
  });

  test('startsOnMasukWithPenjualan', () {
    expect(viewModel.direction, Direction.masuk);
    expect(viewModel.categoryId, 'cat-1');
    expect(viewModel.canSave, isFalse);
  });

  test('switchingToKeluarOffersOnlyMoneyOutCategories', () {
    viewModel.selectDirection(Direction.keluar);

    expect(
      viewModel.categoriesForDirection.every(
        (category) => category.direction == Direction.keluar,
      ),
      isTrue,
    );
    expect(viewModel.categoryId, isNot('cat-1'));
  });

  test('buildsOneBareAmountLinePaidInFullToday', () {
    viewModel.setAmount(1200000);

    final draft = viewModel.buildDraft().toJson();

    expect(draft.containsKey('businessDate'), isFalse);
    expect(draft['source'], 'TYPED');
    expect(draft['total'], 1200000);
    expect(draft['lines'], [
      {
        'itemId': null,
        'itemName': null,
        'categoryId': 'cat-1',
        'quantity': null,
        'unit': null,
        'unitPrice': null,
        'lineTotal': 1200000,
      },
    ]);
    expect(draft['payments'], [
      {'date': '2026-11-16', 'amount': 1200000, 'label': 'cash'},
    ]);
  });

  test('cobaLagiReusesTheKeyButAChangedAmountGetsANewOne', () async {
    adapter.isSaveFailing = true;
    viewModel.setAmount(50000);

    await viewModel.simpan();
    await viewModel.simpan();

    expect(adapter.saveKeys, hasLength(2));
    expect(adapter.saveKeys[1], adapter.saveKeys[0]);
    expect(viewModel.errorMessage, 'Tidak ada koneksi');

    adapter.isSaveFailing = false;
    viewModel.setAmount(60000);
    await viewModel.simpan();

    expect(adapter.saveKeys[2], isNot(adapter.saveKeys[0]));
    expect(viewModel.savedDraft, isNotNull);
  });

  test('aChangedAmountForgetsTheFailedOneKeptOnThePhone', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = UnsentDraftsStore(const FlutterSecureStorage());
    final apiClient = ApiClient(
      Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
    );
    final keptViewModel = KetikViewModel(
      storeRepository: StoreRepository(apiClient),
      draftRepository: DraftRepository(apiClient),
      businessToday: '2026-11-16',
      unsentDraftsStore: store,
    );
    await keptViewModel.loadCategories();
    adapter.isSaveFailing = true;

    keptViewModel.setAmount(50000);
    await keptViewModel.simpan();

    expect([for (final unsent in await store.load()) unsent.draft.total], [
      50000,
    ]);

    keptViewModel.setAmount(60000);
    await keptViewModel.simpan();

    expect([for (final unsent in await store.load()) unsent.draft.total], [
      60000,
    ]);
  });

  group('opened without signal (Q1 bug 2)', () {
    late StoreRepository storeRepository;
    late UnsentDraftsStore store;
    late KetikViewModel offlineViewModel;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      const secureStorage = FlutterSecureStorage();
      final apiClient = ApiClient(
        Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
      );
      storeRepository = StoreRepository(
        apiClient,
        secureStorage: secureStorage,
      );
      store = UnsentDraftsStore(secureStorage);
      offlineViewModel = KetikViewModel(
        storeRepository: storeRepository,
        draftRepository: DraftRepository(apiClient),
        businessToday: '2026-11-16',
        unsentDraftsStore: store,
      );
    });

    test(
      'recordsOnTheCategoriesKeptFromLastTimeAndKeepsTheFailedSave',
      () async {
        await storeRepository.fetchCategories();
        adapter.isOffline = true;

        await offlineViewModel.loadCategories();
        offlineViewModel.setAmount(75000);
        await offlineViewModel.simpan();

        expect(offlineViewModel.categoryId, 'cat-1');
        expect(
          [for (final unsent in await store.load()) unsent.draft.total],
          [75000],
        );
      },
    );
  });
}

class _KeyRecordingAdapter implements HttpClientAdapter {
  final MockApiAdapter _mock = MockApiAdapter(bodiesByRoute: mockBodiesByRoute);
  final List<String> saveKeys = [];
  bool isSaveFailing = false;

  /// Every request fails with no response, as on a phone without signal.
  bool isOffline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (isOffline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    if (options.method == 'POST' && options.path.endsWith('/transactions')) {
      saveKeys.add(options.headers['Idempotency-Key'] as String);
      if (isSaveFailing) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        );
      }
    }
    return _mock.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
