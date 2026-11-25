import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/transaction_repository.dart';
import 'package:malas/model/transaction.dart';
import 'package:malas/model/transaction_filter.dart';

import '../support/recording_adapter.dart';

void main() {
  late RecordingAdapter adapter;
  late TransactionRepository repository;

  setUp(() {
    adapter = RecordingAdapter(bodiesByRoute: mockBodiesByRoute);
    repository = TransactionRepository(
      ApiClient(
        Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
      ),
    );
  });

  test('sendsOnlyTheFiltersThatAreSet', () async {
    await repository.fetchPage(filter: const TransactionFilter());
    expect(adapter.lastRequest.queryParameters, isEmpty);

    await repository.fetchPage(
      filter: const TransactionFilter(
        direction: Direction.keluar,
        isUnpaidOnly: true,
        query: '  gas ',
        focus: FilterFocus(kind: FocusKind.item, id: 'item-3', name: 'Gas'),
      ),
      cursor: 'page-2',
    );
    expect(adapter.lastRequest.queryParameters, {
      'direction': 'OUT',
      'unpaid': 'true',
      'q': 'gas',
      'itemId': 'item-3',
      'cursor': 'page-2',
    });
  });

  test('readsAPageWithTheDerivedFieldsOnEachRow', () async {
    final page = await repository.fetchPage(filter: const TransactionFilter());

    expect(page.transactions, hasLength(5));
    expect(page.transactions.first.editCount, 2);
    expect(page.nextCursor, isNull);
  });

  test('piutangAndUtangCarryDueDatesAndKembalikan', () async {
    final piutang = await repository.fetchPiutang();
    final utang = await repository.fetchUtang();

    expect(adapter.lastRequest.path, '/payables');
    expect(piutang.single.person!.name, 'Pak Budi');
    expect(piutang.single.dueDate, '2026-11-20');
    expect(utang.last.isKembalikan, isTrue);
    expect(utang.last.remaining, -50000);
  });

  test('deleteRestoreAndBayarCallTheirRoutes', () async {
    await repository.delete('trx-1');
    expect(adapter.lastRequest.method, 'DELETE');
    expect(adapter.lastRequest.path, '/transactions/trx-1');

    await repository.restore('trx-1');
    expect(adapter.lastRequest.path, '/transactions/trx-1/restore');

    await repository.pay(transactionId: 'trx-3', amount: 10000);
    expect(adapter.lastRequest.path, '/transactions/trx-3/payments');
    expect(adapter.lastRequest.data, {'amount': 10000});
  });
}
