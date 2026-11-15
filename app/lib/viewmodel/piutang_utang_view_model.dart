import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/transaction_repository.dart';
import '../model/transaction.dart';

/// Piutang and Utang (§7.4): one row per open transaction, with Bayar.
class PiutangUtangViewModel extends ChangeNotifier {
  PiutangUtangViewModel({required this._transactionRepository});

  final TransactionRepository _transactionRepository;

  List<Transaction> _piutang = const [];
  List<Transaction> _utang = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Transaction> get piutang => _piutang;
  List<Transaction> get utang => _utang;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// What others still owe the owner.
  int get piutangTotal => _sumRemaining(_piutang);

  /// What the owner still owes, Kembalikan included as money owed back.
  int get utangTotal => _sumRemaining(_utang);

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _piutang = await _transactionRepository.fetchPiutang();
      _utang = await _transactionRepository.fetchUtang();
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// [amountText] is what the owner typed, dots allowed. Returns false with
  /// [errorMessage] when it is empty or the server refused.
  Future<bool> pay({
    required Transaction transaction,
    required String amountText,
  }) async {
    final digits = amountText.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = digits.isEmpty ? 0 : int.parse(digits);
    if (amount <= 0) {
      _errorMessage = 'Isi jumlah bayar';
      notifyListeners();
      return false;
    }
    try {
      await _transactionRepository.pay(
        transactionId: transaction.id,
        amount: amount,
      );
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return false;
    }
    // The server works out what is left, overpayment included (§4.1).
    await load();
    return true;
  }
}

/// A Kembalikan row counts what is owed back, so it adds to Utang.
int _sumRemaining(List<Transaction> transactions) {
  var total = 0;
  for (final transaction in transactions) {
    total += transaction.remaining.abs();
  }
  return total;
}
