import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/auth_repository.dart';
import '../model/account.dart';

/// Where the app is in its start-up: which top-level screen shows.
enum SessionStage { loading, failed, signedOut, firstRun, ready }

/// Decides between sign-in, first-run setup and the four tabs (§8.1), and
/// whether the trial sheet is due (§8.11).
class SessionViewModel extends ChangeNotifier {
  SessionViewModel({required this._authRepository, required this._now});

  final AuthRepository _authRepository;

  /// The phone clock, used only to tell whether the trial has ended.
  final DateTime Function() _now;

  SessionStage _stage = SessionStage.loading;
  Account? _account;
  String? _errorMessage;
  bool _isTrialSheetDue = false;

  SessionStage get stage => _stage;
  Account? get account => _account;
  String? get errorMessage => _errorMessage;
  bool get isTrialSheetDue => _isTrialSheetDue;

  Future<void> start() async {
    _stage = SessionStage.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final account = await _authRepository.restoreSession();
      if (account == null) {
        _signOutLocally();
      } else {
        await enter(account);
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _authRepository.signOut();
        _signOutLocally();
      } else {
        _errorMessage = error.message;
        _stage = SessionStage.failed;
        notifyListeners();
      }
    }
  }

  /// After sign-in, registration or first-run setup.
  Future<void> enter(Account account) async {
    _account = account;
    _stage = account.isSetUp ? SessionStage.ready : SessionStage.firstRun;
    _isTrialSheetDue =
        account.isSetUp &&
        account.store.isTrialOverAt(_now()) &&
        !await _authRepository.hasSeenTrialSheet();
    notifyListeners();
  }

  /// Any request answered `401` lands here: the token is no longer valid.
  Future<void> handleUnauthorized() async {
    if (_stage == SessionStage.signedOut) return;
    await _authRepository.signOut();
    _signOutLocally();
  }

  /// "Pilih Pro" or "Lanjut Gratis". The December test has no Play Billing
  /// (§18), so Pro is recorded as the owner's choice and nothing is charged.
  Future<void> answerTrialSheet(Plan plan) async {
    final account = _account;
    if (account != null && plan != Plan.gratis) {
      await _authRepository.choosePlan(storeId: account.store.id, plan: plan);
    }
    await _authRepository.markTrialSheetSeen();
    _isTrialSheetDue = false;
    notifyListeners();
  }

  void _signOutLocally() {
    _account = null;
    _stage = SessionStage.signedOut;
    notifyListeners();
  }
}
