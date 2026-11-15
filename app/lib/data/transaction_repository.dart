import '../model/transaction.dart';
import '../model/transaction_filter.dart';
import 'api_client.dart';

/// One page of Catatan, newest first. [nextCursor] is null on the last page.
class TransactionPage {
  const TransactionPage({required this.transactions, required this.nextCursor});

  final List<Transaction> transactions;
  final String? nextCursor;
}

/// Catatan and Piutang/Utang (§7.4, §7.5). Saving and editing a draft is
/// F3's, through the draft screen.
class TransactionRepository {
  TransactionRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<TransactionPage> fetchPage({
    required TransactionFilter filter,
    String? cursor,
  }) async {
    final body = await _apiClient.get(
      '/transactions',
      query: {...filter.toQuery(), 'cursor': ?cursor},
    ) as Map<String, Object?>;
    return TransactionPage(
      transactions: _readTransactions(body['transactions']),
      nextCursor: body['nextCursor'] as String?,
    );
  }

  /// A soft delete. [restore] brings it back while the Batal toast shows.
  Future<void> delete(String transactionId) async {
    await _apiClient.delete('/transactions/$transactionId');
  }

  Future<void> restore(String transactionId) async {
    await _apiClient.post('/transactions/$transactionId/restore');
  }

  /// Money owed to the owner, one row per transaction (§4.1).
  Future<List<Transaction>> fetchPiutang() => _fetchOpen('/receivables');

  /// Money the owner owes, including Kembalikan rows.
  Future<List<Transaction>> fetchUtang() => _fetchOpen('/payables');

  /// Bayar: a payment dated today, which the server resolves (§7.4).
  Future<void> pay({required String transactionId, required int amount}) async {
    await _apiClient.post(
      '/transactions/$transactionId/payments',
      body: {'amount': amount},
    );
  }

  Future<List<Transaction>> _fetchOpen(String path) async {
    final body = await _apiClient.get(path) as Map<String, Object?>;
    return _readTransactions(body['rows']);
  }
}

List<Transaction> _readTransactions(Object? transactionsJson) {
  return [
    for (final transactionJson in transactionsJson as List<Object?>)
      Transaction.fromJson(transactionJson as Map<String, Object?>),
  ];
}
