import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/home_repository.dart';
import '../model/home.dart';

class BerandaViewModel extends ChangeNotifier {
  BerandaViewModel({required this._homeRepository});

  final HomeRepository _homeRepository;

  Home? _home;
  bool _isLoading = false;
  String? _errorMessage;

  Home? get home => _home;
  bool get isLoading => _isLoading;

  /// Set when the last load failed. The last loaded [home] stays on screen,
  /// so a failed pull-to-refresh doesn't blank Beranda.
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _home = await _homeRepository.fetchHome();
    } on ApiException catch (error) {
      // The owner can act on this one: retry, or check the signal.
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
