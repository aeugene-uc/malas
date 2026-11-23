import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/auth_repository.dart';
import '../model/account.dart';

/// Where the app is in its start-up: which top-level screen shows.
enum SessionStage { loading, failed, signedOut, firstRun, ready }

/// Decides between sign-in, first-run setup and the four tabs (§8.1), and
/// whether the trial sheet is due (§8.11).
class SessionViewModel extends ChangeNotifier {
  SessionViewModel({
    required this._authRepository,
    required this._now,
    required this._scheduleReminder,
  });

  final AuthRepository _authRepository;

  /// Sets the phone's evening reminder from a store, or clears it for null.
  final Future<void> Function(Store? store) _scheduleReminder;

  /// The phone clock, used only to tell whether the trial has ended.
  final DateTime Function() _now;

  SessionStage _stage = SessionStage.loading;
  Account? _account;
  String? _errorMessage;
  bool _isTrialSheetDue = false;
  bool _isGuidedEntryDue = false;

  SessionStage get stage => _stage;
  Account? get account => _account;
  String? get errorMessage => _errorMessage;
  bool get isTrialSheetDue => _isTrialSheetDue;

  /// #33: an owner who has just set up a store is walked through one entry
  /// on Beranda. Kept in memory only, so it shows in that first session and
  /// never again.
  bool get isGuidedEntryDue => _isGuidedEntryDue;

  Future<void> start() async {
    _stage = SessionStage.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final account = await _authRepository.restoreSession();
      if (account == null) {
        await _signOutLocally();
      } else {
        await enter(account);
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _authRepository.signOut();
        await _signOutLocally();
      } else {
        _errorMessage = error.message;
        _stage = SessionStage.failed;
        notifyListeners();
      }
    }
  }

  /// After sign-in, registration or first-run setup.
  Future<void> enter(Account account) async {
    final hasJustSetUpStore =
        _stage == SessionStage.firstRun && account.isSetUp;
    _account = account;
    _isGuidedEntryDue = hasJustSetUpStore;
    _stage = account.isSetUp ? SessionStage.ready : SessionStage.firstRun;
    _isTrialSheetDue =
        account.isSetUp &&
        account.store.isTrialOverAt(_now()) &&
        !await _authRepository.hasSeenTrialSheet();
    notifyListeners();
    if (account.isSetUp) await _scheduleReminder(account.store);
  }

  /// After the first save, or "Lewati".
  void finishGuidedEntry() {
    if (!_isGuidedEntryDue) return;
    _isGuidedEntryDue = false;
    notifyListeners();
  }

  /// "Keluar" in Settings.
  Future<void> signOut() async {
    await _authRepository.signOut();
    await _signOutLocally();
  }

  /// Any request answered `401` lands here: the token is no longer valid.
  Future<void> handleUnauthorized() async {
    if (_stage == SessionStage.signedOut) return;
    await _authRepository.signOut();
    await _signOutLocally();
  }

  /// "Pilih Pro" or "Lanjut Gratis". The December test has no Play Billing
  /// (§18), so Pro is recorded as the owner's choice and nothing is charged.
  Future<void> answerTrialSheet(Plan plan) async {
    await choosePlan(plan);
    await _authRepository.markTrialSheetSeen();
    _isTrialSheetDue = false;
    notifyListeners();
  }

  /// Records a paid plan the owner picked. Gratis needs nothing sent.
  Future<void> choosePlan(Plan plan) async {
    final account = _account;
    if (account == null || plan == Plan.gratis) return;
    await _authRepository.choosePlan(storeId: account.store.id, plan: plan);
  }

  Future<void> _signOutLocally() async {
    _account = null;
    _stage = SessionStage.signedOut;
    notifyListeners();
    await _scheduleReminder(null);
  }
}
