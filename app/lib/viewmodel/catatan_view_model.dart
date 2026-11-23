import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/transaction_repository.dart';
import '../model/draft.dart';
import '../model/transaction.dart';
import '../model/transaction_filter.dart';

/// Catatan (§6, §7.5): every entry by date, with search and filters, and
/// delete that can be undone while the Batal toast shows.
class CatatanViewModel extends ChangeNotifier {
  CatatanViewModel({
    required this._transactionRepository,
    FilterFocus? initialFocus,
  }) : _filter = TransactionFilter(focus: initialFocus);

  final TransactionRepository _transactionRepository;

  TransactionFilter _filter;
  List<Transaction> _transactions = const [];
  TransactionFilter? _shownFilter;
  String? _nextCursor;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  TransactionFilter get filter => _filter;
  List<Transaction> get transactions => _transactions;
  bool get hasMore => _nextCursor != null;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    final requestedFilter = _filter;
    try {
      final page = await _transactionRepository.fetchPage(
        filter: requestedFilter,
      );
      // A reply for a filter the owner already changed is dropped.
      if (requestedFilter != _filter) return;
      _transactions = page.transactions;
      _shownFilter = requestedFilter;
      _nextCursor = page.nextCursor;
    } on ApiException catch (error) {
      if (requestedFilter != _filter) return;
      _errorMessage = error.message;
      // Entries for another search or filter would pass as its results.
      if (requestedFilter != _shownFilter) _transactions = const [];
    } finally {
      if (requestedFilter == _filter) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _isLoadingMore || _isLoading) return;
    _isLoadingMore = true;
    notifyListeners();
    final requestedFilter = _filter;
    try {
      final page = await _transactionRepository.fetchPage(
        filter: requestedFilter,
        cursor: cursor,
      );
      if (requestedFilter != _filter) return;
      _transactions = [..._transactions, ...page.transactions];
      _nextCursor = page.nextCursor;
    } on ApiException catch (error) {
      if (requestedFilter != _filter) return;
      _errorMessage = error.message;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Tapping the selected direction again shows both.
  Future<void> toggleDirection(Direction direction) {
    final newDirection = _filter.direction == direction ? null : direction;
    return _apply(_filter.copyWith(direction: () => newDirection));
  }

  Future<void> toggleUnpaidOnly() {
    return _apply(_filter.copyWith(isUnpaidOnly: !_filter.isUnpaidOnly));
  }

  Future<void> search(String query) {
    final isUnchanged = query.trim() == _filter.query.trim();
    // The same search runs again after it failed, as a retry.
    if (isUnchanged && _errorMessage == null) return Future.value();
    return _apply(_filter.copyWith(query: query));
  }

  Future<void> clearFocus() => _apply(_filter.copyWith(focus: () => null));

  /// Takes the entry off the list at once, as the owner expects, and puts
  /// it back if the server refuses. Returns false with [errorMessage] then.
  Future<bool> delete(Transaction transaction) async {
    final previousTransactions = _transactions;
    _transactions = [
      for (final existing in _transactions)
        if (existing.id != transaction.id) existing,
    ];
    notifyListeners();
    try {
      await _transactionRepository.delete(transaction.id);
      return true;
    } on ApiException catch (error) {
      _transactions = previousTransactions;
      _errorMessage = error.message;
      notifyListeners();
      return false;
    }
  }

  /// Batal on the toast after a delete.
  Future<void> undoDelete(Transaction transaction) async {
    try {
      await _transactionRepository.restore(transaction.id);
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return;
    }
    await load();
  }

  /// Returns null with [errorMessage] when the server could not build it.
  Future<AiReadResult?> fetchCopyDraft(
    Transaction transaction,
    EntryCopy copy,
  ) async {
    _errorMessage = null;
    try {
      return await _transactionRepository.fetchCopyDraft(
        transactionId: transaction.id,
        copy: copy,
      );
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return null;
    }
  }

  /// Null when it failed; [errorMessage] says why.
  Future<String?> fetchBusinessToday() async {
    _errorMessage = null;
    try {
      return await _transactionRepository.fetchBusinessToday();
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return null;
    }
  }

  /// Null when it failed; [errorMessage] says why.
  Future<List<EditRecord>?> fetchHistory(Transaction transaction) async {
    _errorMessage = null;
    try {
      return await _transactionRepository.fetchHistory(transaction.id);
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> _apply(TransactionFilter filter) {
    _filter = filter;
    _nextCursor = null;
    return load();
  }
}
