import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/draft_repository.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/mock_transaction_store.dart';
import 'package:malas/data/transaction_repository.dart';
import 'package:malas/model/draft.dart';
import 'package:malas/model/transaction.dart';
import 'package:malas/model/transaction_filter.dart';

void main() {
  late TransactionRepository repository;
  late DraftRepository draftRepository;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
      ..httpClientAdapter = MockApiAdapter(
        bodiesByRoute: {...mockBodiesByRoute, ...MockTransactionStore().routes},
      );
    repository = TransactionRepository(ApiClient(dio));
    draftRepository = DraftRepository(ApiClient(dio));
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

  Future<Transaction> findEntry(String id) async {
    final page = await repository.fetchPage(filter: const TransactionFilter());
    return page.transactions.singleWhere((transaction) => transaction.id == id);
  }

  test('simpanAddsTheReturAndMarksTheEntryItTakesBack', () async {
    final retur = await repository.fetchCopyDraft(
      transactionId: 'trx-2',
      copy: EntryCopy.retur,
    );

    final saved = await draftRepository.save(
      retur.drafts.single,
      idempotencyKey: 'retur-gas',
    );

    expect((await findEntry(saved.transaction.id)).total, -25000);
    expect((await findEntry('trx-2')).hasRetur, isTrue);
  });

  test('ubahKeepsTheChangedQuantity', () async {
    final draft = Draft.fromTransaction(await findEntry('trx-2'));
    draft.lines.single.quantity = '2';

    await draftRepository.edit('trx-2', draft);

    expect((await findEntry('trx-2')).lines.single.quantity, '2');
  });

  test('riwayatHasOneVersionPerEdit', () async {
    expect(await repository.fetchHistory('trx-1'), hasLength(2));

    final draft = Draft.fromTransaction(await findEntry('trx-1'));
    await draftRepository.edit('trx-1', draft);

    expect(await repository.fetchHistory('trx-1'), hasLength(3));
  });
}
