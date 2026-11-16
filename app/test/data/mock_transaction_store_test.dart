import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/mock_transaction_store.dart';
import 'package:malas/data/transaction_repository.dart';
import 'package:malas/model/transaction.dart';
import 'package:malas/model/transaction_filter.dart';

void main() {
  late TransactionRepository repository;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
      ..httpClientAdapter = MockApiAdapter(
        bodiesByRoute: {...mockBodiesByRoute, ...MockTransactionStore().routes},
      );
    repository = TransactionRepository(ApiClient(dio));
  });

  Future<List<String>> idsFor(TransactionFilter filter) async {
    final page = await repository.fetchPage(filter: filter);
    return [for (final transaction in page.transactions) transaction.id];
  }

  test('narrowsTheListByEachFilter', () async {
    expect(await idsFor(const TransactionFilter()), hasLength(5));
    expect(await idsFor(const TransactionFilter(direction: Direction.keluar)), [
      'trx-2',
      'trx-4',
    ]);
    expect(await idsFor(const TransactionFilter(isUnpaidOnly: true)), [
      'trx-3',
      'trx-4',
    ]);
    expect(await idsFor(const TransactionFilter(query: 'NASI')), [
      'trx-1',
      'trx-5',
    ]);
    expect(
      await idsFor(
        const TransactionFilter(
          focus: FilterFocus(
            kind: FocusKind.category,
            id: 'cat-bahan',
            name: 'Bahan',
          ),
        ),
      ),
      ['trx-4'],
    );
    expect(
      await idsFor(
        const TransactionFilter(
          focus: FilterFocus(kind: FocusKind.item, id: 'item-3', name: 'Gas'),
        ),
      ),
      ['trx-2'],
    );
  });

  test('aDeleteStaysDeletedUntilRestored', () async {
    await repository.delete('trx-2');
    expect(await idsFor(const TransactionFilter()), isNot(contains('trx-2')));

    await repository.restore('trx-2');
    expect(await idsFor(const TransactionFilter()), contains('trx-2'));
  });

  test('bayarLowersWhatIsLeftUntilItLeavesPiutang', () async {
    await repository.pay(transactionId: 'trx-3', amount: 10000);
    expect((await repository.fetchPiutang()).single.remaining, 20000);

    await repository.pay(transactionId: 'trx-3', amount: 20000);
    expect(await repository.fetchPiutang(), isEmpty);
  });

  test('overpaidMoneyInIsListedUnderUtangAsKembalikan', () async {
    final utang = await repository.fetchUtang();

    expect(utang.map((transaction) => transaction.id), ['trx-4', 'trx-5']);
    expect(utang.last.isKembalikan, isTrue);
  });
}
