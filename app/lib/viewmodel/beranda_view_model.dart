import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/home_repository.dart';
import '../data/unsent_drafts_store.dart';
import '../model/home.dart';

class BerandaViewModel extends ChangeNotifier {
  BerandaViewModel({
    required this._homeRepository,
    required this._unsentDraftsStore,
  });

  final HomeRepository _homeRepository;
  final UnsentDraftsStore _unsentDraftsStore;

  Home? _home;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasReadUnsentDrafts = false;
  List<UnsentDraft> _unsentDrafts = const [];

  Home? get home => _home;
  bool get isLoading => _isLoading;

  /// Set when the last load failed. The last loaded [home] stays on screen,
  /// so a failed pull-to-refresh doesn't blank Beranda.
  String? get errorMessage => _errorMessage;

  /// Drafts whose Simpan failed before the app was last closed (#25). They
  /// are read once, after the first /home gives the business date to open
  /// them on. Taking them empties the list, so Beranda opens them only once.
  List<UnsentDraft> takeUnsentDrafts() {
    final unsentDrafts = _unsentDrafts;
    _unsentDrafts = const [];
    return unsentDrafts;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _home = await _homeRepository.fetchHome();
      if (!_hasReadUnsentDrafts) {
        _hasReadUnsentDrafts = true;
        _unsentDrafts = await _unsentDraftsStore.load();
      }
    } on ApiException catch (error) {
      // The owner can act on this one: retry, or check the signal.
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
