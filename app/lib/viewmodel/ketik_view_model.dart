import 'dart:async';

// Flutter's foundation has its own Category annotation.
import 'package:flutter/foundation.dart' hide Category;

import '../data/api_client.dart';
import '../data/draft_repository.dart';
import '../data/store_repository.dart';
import '../data/unsent_drafts_store.dart';
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
    this._unsentDraftsStore,
  });

  final StoreRepository _storeRepository;
  final DraftRepository _draftRepository;
  final String _businessToday;

  /// Keeps a failed save on the phone (#25). Null when it need not be kept.
  final UnsentDraftsStore? _unsentDraftsStore;

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

  /// Opened without signal on a phone that never fetched them: Coba lagi
  /// fetches the categories instead of saving.
  bool get isMissingCategories => _categories.isEmpty && _errorMessage != null;

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
    _dropPendingSave();
    notifyListeners();
  }

  void setAmount(int? amount) {
    _amount = amount;
    _dropPendingSave();
    notifyListeners();
  }

  void selectCategory(String categoryId) {
    _categoryId = categoryId;
    _dropPendingSave();
    notifyListeners();
  }

  Future<void> simpan() async {
    if (!canSave) return;
    final pendingSave = _pendingSave ??= DraftViewModel(
      draftRepository: _draftRepository,
      businessToday: _businessToday,
      drafts: [buildDraft()],
      unsentDraftsStore: _unsentDraftsStore,
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

  /// A changed entry is a different save with a new key, so the failed one
  /// kept on the phone goes too. Otherwise the next open would offer both.
  void _dropPendingSave() {
    final dropped = _pendingSave;
    _pendingSave = null;
    if (dropped != null) unawaited(dropped.forgetUnsent());
  }

  /// Picked by name, not position: the server sorts categories by name, which
  /// put Ambil pribadi, not counted in profit (§4.2), first for Keluar.
  String? _defaultCategoryId() {
    final candidates = categoriesForDirection;
    if (candidates.isEmpty) return null;
    final defaultName = _direction == Direction.masuk
        ? 'Penjualan'
        : 'Barang dagangan';
    final named = candidates.where((c) => c.name == defaultName);
    return (named.isEmpty ? candidates.first : named.first).id;
  }
}
