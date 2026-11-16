import 'mock_api_adapter.dart';
import 'mock_bodies.dart';

/// The sample entries for running the app on mocks, with state: filters and
/// search narrow the list, a delete stays deleted until restored, and Bayar
/// lowers what is left. It stands in for S5/S6 until those routes exist.
/// Tests that need fixed replies keep using [mockBodiesByRoute] alone.
class MockTransactionStore {
  MockTransactionStore()
    : _transactions = [
        for (final transaction in sampleTransactions)
          Map<String, Object?>.of(transaction),
      ];

  final List<Map<String, Object?>> _transactions;
  final Set<String> _deletedIds = {};

  /// The routes this store answers, to lay over [mockBodiesByRoute].
  Map<String, Object> get routes => {
    'GET /transactions': _list,
    'DELETE /transactions/:id': _delete,
    'POST /transactions/:id/restore': _restore,
    'POST /transactions/:id/payments': _pay,
    'GET /receivables': _receivables,
    'GET /payables': _payables,
  };

  Object _list(MockRequest request) {
    final query = request.query;
    return {
      'transactions': [
        for (final transaction in _visible)
          if (_matches(transaction, query)) transaction,
      ],
      'nextCursor': null,
    };
  }

  Object _delete(MockRequest request) {
    _deletedIds.add(request.segmentAfter('transactions'));
    return <String, Object>{};
  }

  Object _restore(MockRequest request) {
    _deletedIds.remove(request.segmentAfter('transactions'));
    return <String, Object>{};
  }

  Object _pay(MockRequest request) {
    final transaction = _find(request.segmentAfter('transactions'));
    final amount = request.body['amount']! as int;
    final paid = (transaction['paid']! as int) + amount;
    transaction['paid'] = paid;
    transaction['remaining'] = (transaction['total']! as int) - paid;
    return {
      'payment': {'id': 'pay-${transaction['id']}', 'amount': amount},
    };
  }

  /// Money in still owed to the owner.
  Object _receivables(MockRequest request) {
    return {
      'rows': [
        for (final transaction in _visible)
          if (transaction['direction'] == 'IN' && _remaining(transaction) > 0)
            transaction,
      ],
    };
  }

  /// Money out still owed, plus money in that was overpaid (Kembalikan).
  Object _payables(MockRequest request) {
    return {
      'rows': [
        for (final transaction in _visible)
          if (transaction['direction'] == 'OUT'
              ? _remaining(transaction) > 0
              : _remaining(transaction) < 0)
            transaction,
      ],
    };
  }

  Iterable<Map<String, Object?>> get _visible =>
      _transactions.where((t) => !_deletedIds.contains(t['id']));

  Map<String, Object?> _find(String id) {
    return _transactions.firstWhere((transaction) => transaction['id'] == id);
  }
}

int _remaining(Map<String, Object?> transaction) =>
    transaction['remaining']! as int;

/// The `GET /transactions` filters, as the backend contract defines them.
bool _matches(Map<String, Object?> transaction, Map<String, Object?> query) {
  final lines = (transaction['lines']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final person = transaction['person'] as Map<String, Object?>?;
  final direction = query['direction'];
  if (direction != null && transaction['direction'] != direction) return false;
  if (query['unpaid'] == 'true' && _remaining(transaction) <= 0) return false;
  if (query['itemId'] case final itemId?) {
    if (!lines.any((line) => _refId(line['item']) == itemId)) return false;
  }
  if (query['categoryId'] case final categoryId?) {
    if (!lines.any((line) => _refId(line['category']) == categoryId)) {
      return false;
    }
  }
  if (query['personId'] case final personId?) {
    if (person?['id'] != personId) return false;
  }
  if (query['q'] case final String searchText) {
    final names = [
      ?person?['name'] as String?,
      for (final line in lines) ?_refName(line['item']),
      for (final line in lines) ?_refName(line['category']),
    ];
    final needle = searchText.toLowerCase();
    if (!names.any((name) => name.toLowerCase().contains(needle))) {
      return false;
    }
  }
  return true;
}

String? _refId(Object? ref) => (ref as Map<String, Object?>?)?['id'] as String?;

String? _refName(Object? ref) =>
    (ref as Map<String, Object?>?)?['name'] as String?;
