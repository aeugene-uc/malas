import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/auth_repository.dart';
import '../model/account.dart';

enum SignInMode { masuk, daftar }

/// Phone number and password (#100). Daftar also asks the owner's name.
class SignInViewModel extends ChangeNotifier {
  SignInViewModel({required this._authRepository});

  final AuthRepository _authRepository;

  SignInMode _mode = SignInMode.masuk;
  bool _isSubmitting = false;
  String? _errorMessage;

  SignInMode get mode => _mode;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  void selectMode(SignInMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _errorMessage = null;
    notifyListeners();
  }

  /// Returns null when the form is incomplete or the server refused, with
  /// [errorMessage] saying why.
  Future<Account?> submit({
    required String name,
    required String phone,
    required String password,
  }) async {
    final isNameMissing = _mode == SignInMode.daftar && name.trim().isEmpty;
    if (isNameMissing || phone.trim().isEmpty || password.isEmpty) {
      _errorMessage = 'Lengkapi semua kolom';
      notifyListeners();
      return null;
    }
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return switch (_mode) {
        SignInMode.masuk => await _authRepository.signIn(
          phone: phone.trim(),
          password: password,
        ),
        SignInMode.daftar => await _authRepository.register(
          name: name.trim(),
          phone: phone.trim(),
          password: password,
        ),
      };
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
