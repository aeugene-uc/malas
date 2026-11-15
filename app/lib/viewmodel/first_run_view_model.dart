import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/auth_repository.dart';
import '../model/account.dart';

/// First run (§7.1): business name, "Usaha kamu apa?" and the consent line.
class FirstRunViewModel extends ChangeNotifier {
  FirstRunViewModel({required Account account, required this._authRepository})
    : _account = account,
      _selectedTypes = {...account.store.businessTypes};

  final Account _account;
  final AuthRepository _authRepository;

  final Set<BusinessType> _selectedTypes;
  bool _isSubmitting = false;
  String? _errorMessage;

  String get initialStoreName => _account.store.name;
  Set<BusinessType> get selectedTypes => Set.unmodifiable(_selectedTypes);
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  void toggleType(BusinessType type) {
    if (!_selectedTypes.remove(type)) _selectedTypes.add(type);
    notifyListeners();
  }

  /// Returns the updated account, or null with [errorMessage] saying why.
  Future<Account?> submit({required String storeName}) async {
    if (storeName.trim().isEmpty || _selectedTypes.isEmpty) {
      _errorMessage = 'Isi nama usaha dan pilih jenis usaha';
      notifyListeners();
      return null;
    }
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // Every write is refused until consent is given, the store setup too.
      if (!_account.user.hasConsented) await _authRepository.giveConsent();
      await _authRepository.saveStoreSetup(
        storeId: _account.store.id,
        storeName: storeName.trim(),
        businessTypes: _selectedTypes,
      );
      return await _authRepository.fetchAccount();
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
