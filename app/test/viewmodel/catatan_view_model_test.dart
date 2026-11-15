import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/transaction_repository.dart';
import 'package:malas/model/transaction.dart';
import 'package:malas/model/transaction_filter.dart';
import 'package:malas/viewmodel/catatan_view_model.dart';
import 'package:malas/viewmodel/piutang_utang_view_model.dart';

import '../support/recording_adapter.dart';

void main() {
  late RecordingAdapter adapter;

  TransactionRepository buildRepository([Map<String, Object>? bodiesByRoute]) {
    adapter = RecordingAdapter(
      bodiesByRoute: bodiesByRoute ?? mockBodiesByRoute,
    );
    return TransactionRepository(
      ApiClient(
        Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
      ),
    );
  }

  group('Catatan', () {
    test('opensOnEveryEntryOrOnTheAnalisisRowItCameFrom', () async {
      final everything = CatatanViewModel(
        transactionRepository: buildRepository(),
      );
      await everything.load();
      expect(everything.transactions, hasLength(5));
      expect(adapter.lastRequest.queryParameters, isEmpty);

      final focused = CatatanViewModel(
        transactionRepository: buildRepository(),
        initialFocus: const FilterFocus(
          kind: FocusKind.category,
          id: 'cat-bahan',
          name: 'Bahan',
        ),
      );
      await focused.load();
      expect(adapter.lastRequest.queryParameters, {'categoryId': 'cat-bahan'});
    });

    test('tappingADirectionTwiceShowsBothAgain', () async {
      final viewModel = CatatanViewModel(
        transactionRepository: buildRepository(),
      );

      await viewModel.toggleDirection(Direction.keluar);
      expect(adapter.lastRequest.queryParameters['direction'], 'OUT');

      await viewModel.toggleDirection(Direction.keluar);
      expect(
        adapter.lastRequest.queryParameters.containsKey('direction'),
        isFalse,
      );
    });

    test('searchingTheSameWordsAgainSendsNothing', () async {
      final viewModel = CatatanViewModel(
        transactionRepository: buildRepository(),
      );
      await viewModel.search('gas');
      final requestCount = adapter.requests.length;

      await viewModel.search(' gas ');

      expect(adapter.requests, hasLength(requestCount));
    });

    test('deleteTakesTheEntryOffAtOnceAndBatalRestoresIt', () async {
      final viewModel = CatatanViewModel(
        transactionRepository: buildRepository(),
      );
      await viewModel.load();
      final gas = viewModel.transactions[1];

      final isDeleted = await viewModel.delete(gas);
      expect(isDeleted, isTrue);
      expect(viewModel.transactions.map((t) => t.id), isNot(contains(gas.id)));
      expect(adapter.lastRequest.method, 'DELETE');

      await viewModel.undoDelete(gas);
      expect(
        adapter.requests.any(
          (request) => request.path == '/transactions/${gas.id}/restore',
        ),
        isTrue,
      );
      expect(viewModel.transactions.map((t) => t.id), contains(gas.id));
    });

    test('aRefusedDeletePutsTheEntryBack', () async {
      final viewModel = CatatanViewModel(
        transactionRepository: buildRepository({
          'GET /transactions': mockBodiesByRoute['GET /transactions']!,
        }),
      );
      await viewModel.load();
      final first = viewModel.transactions.first;

      final isDeleted = await viewModel.delete(first);

      expect(isDeleted, isFalse);
      expect(viewModel.transactions.first.id, first.id);
      expect(viewModel.errorMessage, isNotNull);
    });
  });

  group('Piutang/Utang', () {
    test('totalsCountKembalikanAsMoneyOwedBack', () async {
      final viewModel = PiutangUtangViewModel(
        transactionRepository: buildRepository(),
      );

      await viewModel.load();

      expect(viewModel.piutangTotal, 30000);
      expect(viewModel.utangTotal, 1200000 + 50000);
    });

    test('bayarSendsTheTypedAmountAndReloads', () async {
      final viewModel = PiutangUtangViewModel(
        transactionRepository: buildRepository(),
      );
      await viewModel.load();

      final isPaid = await viewModel.pay(
        transaction: viewModel.piutang.single,
        amountText: '10.000',
      );

      expect(isPaid, isTrue);
      final payment = adapter.requests.firstWhere(
        (request) => request.path.endsWith('/payments'),
      );
      expect(payment.data, {'amount': 10000});
      expect(adapter.lastRequest.path, '/payables');
    });

    test('bayarNeedsAnAmount', () async {
      final viewModel = PiutangUtangViewModel(
        transactionRepository: buildRepository(),
      );
      await viewModel.load();
      final requestCount = adapter.requests.length;

      final isPaid = await viewModel.pay(
        transaction: viewModel.piutang.single,
        amountText: '',
      );

      expect(isPaid, isFalse);
      expect(viewModel.errorMessage, 'Isi jumlah bayar');
      expect(adapter.requests, hasLength(requestCount));
    });
  });
}
