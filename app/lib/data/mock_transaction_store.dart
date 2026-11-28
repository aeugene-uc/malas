import 'mock_api_adapter.dart';
import 'mock_bodies.dart';

/// The sample entries for running the app on mocks, with state: filters and
/// search narrow the list, Simpan adds an entry, Ubah replaces one, a delete
/// stays deleted until restored, and Bayar lowers what is left. It stands in for S5/S6 until those routes exist.
/// Tests that need fixed replies keep using [mockBodiesByRoute] alone.
class MockTransactionStore {
  MockTransactionStore()
    : _transactions = [
        for (final transaction in sampleTransactions)
          Map<String, Object?>.of(transaction),
      ] {
    // A sample marked as edited needs that many versions behind Riwayat.
    for (final transaction in _transactions) {
      final editCount = transaction['editCount']! as int;
      _historyById[transaction['id']! as String] = [
        for (var version = editCount; version > 0; version--)
          _historyEntry(transaction, version: version),
      ];
    }
  }

  final List<Map<String, Object?>> _transactions;
  final Map<String, List<Map<String, Object?>>> _historyById = {};
  final Set<String> _deletedIds = {};

  /// The routes this store answers, to lay over [mockBodiesByRoute].
  Map<String, Object> get routes => {
    'GET /transactions': _list,
    'POST /transactions': _save,
    'PATCH /transactions/:id': _edit,
    'GET /transactions/:id/history': _history,
    'DELETE /transactions/:id': _delete,
    'POST /transactions/:id/restore': _restore,
    'POST /transactions/:id/payments': _pay,
    'POST /transactions/:id/repeat': (MockRequest request) =>
        _copyDraft(request, isRetur: false),
    'POST /transactions/:id/retur': (MockRequest request) =>
        _copyDraft(request, isRetur: true),
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

  /// Simpan: the draft becomes a new entry at the top of the list, and a
  /// Retur marks the entry it takes back.
  Object _save(MockRequest request) {
    final body = request.body;
    final id = 'trx-new-${_transactions.length}';
    final total = body['total']! as int;
    final paid = [
      for (final payment
          in (body['payments']! as List<Object?>).cast<Map<String, Object?>>())
        payment['amount']! as int,
    ].fold(0, (sum, amount) => sum + amount);
    final personName = body['personName'] as String?;
    final transaction = <String, Object?>{
      'id': id,
      'businessDate': body['businessDate'] ?? _mockToday,
      'direction': body['direction'],
      'total': total,
      'paid': paid,
      'remaining': total - paid,
      'editCount': 0,
      'hasRetur': false,
      'person': personName == null
          ? null
          : {'id': body['personId'] ?? 'person-$id', 'name': personName},
      'dueDate': body['dueDate'],
      'lines': _linesFromDraft(body, transactionId: id),
    };
    _transactions.insert(0, transaction);
    if (body['linkedTransactionId'] case final String returnedId) {
      _find(returnedId)['hasRetur'] = true;
    }
    return {'transaction': transaction, 'warnings': <Object>[]};
  }

  /// Ubah: the new date, total and lines replace the old, whose date and
  /// total go to history.
  Object _edit(MockRequest request) {
    final id = request.segmentAfter('transactions');
    final transaction = _find(id);
    (_historyById[id] ??= []).insert(
      0,
      _historyEntry(
        transaction,
        version: (transaction['editCount']! as int) + 1,
      ),
    );
    final total = request.body['total']! as int;
    transaction['businessDate'] =
        request.body['businessDate'] ?? transaction['businessDate'];
    transaction['lines'] = _linesFromDraft(request.body, transactionId: id);
    // As the server does, an entry paid in full stays paid in full.
    if (transaction['paid'] == transaction['total']) {
      transaction['paid'] = total;
    }
    transaction['total'] = total;
    transaction['remaining'] = total - (transaction['paid']! as int);
    transaction['editCount'] = (transaction['editCount']! as int) + 1;
    return {'transaction': transaction, 'warnings': <Object>[]};
  }

  Object _history(MockRequest request) {
    return {
      'history': _historyById[request.segmentAfter('transactions')] ?? [],
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

  /// The server's Ulangi and Retur drafts: Ulangi at the old price, paid in
  /// full when the original was; Retur at negative quantities, linked back.
  Object _copyDraft(MockRequest request, {required bool isRetur}) {
    final transaction = _find(request.segmentAfter('transactions'));
    final sign = isRetur ? -1 : 1;
    final lines = [
      for (final line
          in (transaction['lines']! as List<Object?>)
              .cast<Map<String, Object?>>())
        {
          'itemId': _refId(line['item']),
          'itemName': _refName(line['item']),
          'categoryId': _refId(line['category']),
          'quantity': switch (line['quantity']) {
            final String quantity when isRetur => '-$quantity',
            final quantity => quantity,
          },
          'unit': line['unit'],
          'unitPrice': null,
          'lineTotal': sign * (line['lineTotal']! as int),
        },
    ];
    final total = sign * (transaction['total']! as int);
    final person = transaction['person'] as Map<String, Object?>?;
    final isPaidInFull = _remaining(transaction) <= 0;
    return {
      'drafts': [
        {
          'businessDate': _mockToday,
          'direction': transaction['direction'],
          'total': total,
          'personId': person?['id'],
          'personName': person?['name'],
          'dueDate': null,
          'source': 'TYPED',
          'inputId': null,
          'note': null,
          'linkedTransactionId': isRetur ? transaction['id'] : null,
          'lines': lines,
          'payments': [
            if (!isRetur && isPaidInFull)
              {'date': _mockToday, 'amount': total, 'label': 'cash'},
          ],
        },
      ],
      'warnings': <Object>[],
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

/// One Riwayat row: the entry as it stood before edit number [version].
Map<String, Object?> _historyEntry(
  Map<String, Object?> transaction, {
  required int version,
}) {
  return {
    'id': 'edit-${transaction['id']}-$version',
    'at': '2026-11-11T03:00:00.000Z',
    'previous': {
      'businessDate': transaction['businessDate'],
      'total': transaction['total'],
    },
  };
}

/// A draft's lines in the shape saved entries carry: item and category as
/// `{id, name}`, the category named from the mock category list.
List<Map<String, Object?>> _linesFromDraft(
  Map<String, Object?> draftBody, {
  required String transactionId,
}) {
  final draftLines = (draftBody['lines']! as List<Object?>)
      .cast<Map<String, Object?>>();
  return [
    for (final (index, line) in draftLines.indexed)
      {
        'id': '$transactionId-line-$index',
        'item': switch (line['itemName']) {
          final String itemName => {
            'id': line['itemId'] ?? 'item-$transactionId-$index',
            'name': itemName,
          },
          _ => null,
        },
        'category': _categoryRef(line['categoryId'] as String?),
        'quantity': line['quantity'],
        'unit': line['unit'],
        'unitPrice': line['unitPrice'],
        'lineTotal': line['lineTotal'],
        'discount': 0,
      },
  ];
}

Map<String, Object?>? _categoryRef(String? categoryId) {
  if (categoryId == null) return null;
  final categoriesBody = mockBodiesByRoute['GET /categories']! as Map;
  final categories = (categoriesBody['categories'] as List<Object?>)
      .cast<Map<String, Object?>>();
  final name = categories
      .where((category) => category['id'] == categoryId)
      .firstOrNull?['name'];
  return {'id': categoryId, 'name': name ?? categoryId};
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

/// The business day the mock Beranda reports.
const _mockToday = '2026-11-11';
