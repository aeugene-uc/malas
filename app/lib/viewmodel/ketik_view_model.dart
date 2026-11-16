// Flutter's foundation has its own Category annotation.
import 'package:flutter/foundation.dart' hide Category;

import '../data/api_client.dart';
import '../data/draft_repository.dart';
import '../data/store_repository.dart';
import '../model/category.dart';
import '../model/draft.dart';
import '../model/transaction.dart';
import 'draft_view_model.dart';

/// Ketik's quick amount (spec §7.2, §8.3): Masuk or Keluar, an amount and a
/// category, saved at once. It never calls the AI (§5.7).
class KetikViewModel extends ChangeNotifier {
  KetikViewModel({
    required this._storeRepository,
    required this._draftRepository,
    required this._businessToday,
  });

  final StoreRepository _storeRepository;
  final DraftRepository _draftRepository;
  final String _businessToday;

  List<Category> _categories = const [];
  Direction _direction = Direction.masuk;
  int? _amount;
  String? _categoryId;
  bool _isLoading = false;
  String? _errorMessage;

  /// Kept across a failed save, so Coba lagi reuses its Idempotency-Key.
  /// Any change to the entry drops it, because that is a different save.
  DraftViewModel? _pendingSave;
  DraftViewModel? _savedDraft;

  Direction get direction => _direction;
  int? get amount => _amount;
  String? get categoryId => _categoryId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Set once the save went through; the caller shows Batal with it.
  DraftViewModel? get savedDraft => _savedDraft;

  List<Category> get categoriesForDirection => [
    for (final category in _categories)
      if (category.direction == _direction) category,
  ];

  bool get canSave => !_isLoading && (_amount ?? 0) > 0 && _categoryId != null;

  Future<void> loadCategories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _categories = await _storeRepository.fetchCategories();
      _categoryId = _defaultCategoryId();
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectDirection(Direction direction) {
    if (direction == _direction) return;
    _direction = direction;
    _categoryId = _defaultCategoryId();
    _pendingSave = null;
    notifyListeners();
  }

  void setAmount(int? amount) {
    _amount = amount;
    _pendingSave = null;
    notifyListeners();
  }

  void selectCategory(String categoryId) {
    _categoryId = categoryId;
    _pendingSave = null;
    notifyListeners();
  }

  Future<void> simpan() async {
    if (!canSave) return;
    final pendingSave = _pendingSave ??= DraftViewModel(
      draftRepository: _draftRepository,
      businessToday: _businessToday,
      drafts: [buildDraft()],
    );
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    await pendingSave.simpan();
    _isLoading = false;
    _errorMessage = pendingSave.errorMessage;
    if (pendingSave.isAllSaved) _savedDraft = pendingSave;
    notifyListeners();
  }

  /// One bare-amount line, paid in full today: "Omzet hari ini 1,2 juta" is a
  /// complete entry (§4.1). No date is sent, so the server resolves today.
  @visibleForTesting
  Draft buildDraft() {
    final amount = _amount!;
    return Draft(
      businessDate: null,
      direction: _direction,
      total: amount,
      personId: null,
      personName: null,
      dueDate: null,
      source: 'TYPED',
      inputId: null,
      note: null,
      lines: [
        DraftLine(
          itemId: null,
          itemName: null,
          categoryId: _categoryId,
          quantity: null,
          unit: null,
          unitPrice: null,
          lineTotal: amount,
        ),
      ],
      payments: [
        DraftPayment(date: _businessToday, amount: amount, label: 'cash'),
      ],
    );
  }

  /// Sales for money in. For money out, the first expense category the store
  /// has, which is Barang dagangan in the fixed list.
  String? _defaultCategoryId() {
    final candidates = categoriesForDirection;
    if (candidates.isEmpty) return null;
    final penjualan = candidates.where((c) => c.name == 'Penjualan');
    return (penjualan.isEmpty ? candidates.first : penjualan.first).id;
  }
}
