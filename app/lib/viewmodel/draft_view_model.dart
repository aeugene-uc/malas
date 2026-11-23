import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/draft_repository.dart';
import '../data/unsent_drafts_store.dart';
import '../model/draft.dart';

/// The date chip at the top of the draft screen (spec §7.3).
enum DateChoice { hariIni, kemarin, pilihTanggal }

/// The draft screen: the owner checks every draft from one read, fixes what
/// is wrong, and saves them all with Simpan (spec §7.3).
class DraftViewModel extends ChangeNotifier {
  /// [idempotencyKeys] and [isUnsent] reopen drafts kept on the phone after
  /// a failed Simpan, with the keys they were first sent with (#25).
  DraftViewModel({
    required this._draftRepository,
    required this._businessToday,
    required this.drafts,
    this.warnings = const [],
    this._unsentDraftsStore,
    this.editingTransactionId,
    List<String>? idempotencyKeys,
    bool isUnsent = false,
  }) : _idempotencyKeys =
           idempotencyKeys ??
           [for (final _ in drafts) generateIdempotencyKey()],
       _saveResults = List<SaveResult?>.filled(drafts.length, null),
       _errorMessage = isUnsent ? unsentMessage : null;

  /// Shown on drafts reopened from the phone, so Simpan reads Coba lagi.
  static const String unsentMessage = 'Belum tersimpan';

  final DraftRepository _draftRepository;

  /// Null when the drafts need not outlive the screen.
  final UnsentDraftsStore? _unsentDraftsStore;

  /// Today's business date as the server computed it (from `GET /home`).
  /// Kemarin is counted from this, never from the phone's clock.
  final String _businessToday;

  final List<Draft> drafts;
  final List<ReadWarning> warnings;

  /// Set by Ubah: Simpan replaces this entry instead of adding one.
  final String? editingTransactionId;

  bool get isEditing => editingTransactionId != null;

  /// One key per draft, made when the draft opens, so every retry of its
  /// Simpan reuses it and the server can't record it twice.
  final List<String> _idempotencyKeys;
  final List<SaveResult?> _saveResults;

  late DateChoice _dateChoice = _chipFor(
    businessDate: businessDate,
    businessToday: _businessToday,
  );
  bool _isSaving = false;
  String? _errorMessage;

  String get businessToday => _businessToday;
  DateChoice get dateChoice => _dateChoice;
  bool get isSaving => _isSaving;

  /// The server's message from a failed Simpan or Batal. The drafts stay
  /// open, and Simpan again is Coba lagi.
  String? get errorMessage => _errorMessage;

  bool get isAllSaved => _saveResults.every((result) => result != null);

  List<SaveResult> get saveResults => _saveResults.nonNulls.toList();

  /// The date the drafts will save under; null means Hari ini.
  String? get businessDate => drafts.isEmpty ? null : drafts.first.businessDate;

  void selectDate(DateChoice choice, {String? pickedDate}) {
    final businessDate = switch (choice) {
      DateChoice.hariIni => null,
      DateChoice.kemarin => addDaysToDate(_businessToday, -1),
      DateChoice.pilihTanggal =>
        pickedDate ?? (throw ArgumentError('pilihTanggal needs a pickedDate')),
    };
    for (final draft in drafts) {
      draft.moveToDate(
        businessDate: businessDate,
        businessToday: _businessToday,
      );
    }
    _dateChoice = choice;
    notifyListeners();
  }

  /// Applies the owner's change to one line, then brings the draft's
  /// provisional total back in step with its lines.
  void editLine({
    required int draftIndex,
    required int lineIndex,
    required void Function(DraftLine line) edit,
  }) {
    final draft = drafts[draftIndex];
    edit(draft.lines[lineIndex]);
    draft.recomputeTotal();
    notifyListeners();
  }

  List<ReadWarning> warningsFor({required int draftIndex, int? lineIndex}) {
    return [
      for (final warning in warnings)
        if (warning.draftIndex == draftIndex && warning.lineIndex == lineIndex)
          warning,
    ];
  }

  /// Saves every draft not saved yet, in order. It stops at the first
  /// failure; calling it again retries only the drafts still unsaved.
  Future<void> simpan() async {
    if (_isSaving) return;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      for (var index = 0; index < drafts.length; index++) {
        if (_saveResults[index] != null) continue;
        _saveResults[index] = switch (editingTransactionId) {
          final transactionId? => await _draftRepository.edit(
            transactionId,
            drafts[index],
          ),
          null => await _draftRepository.save(
            drafts[index],
            idempotencyKey: _idempotencyKeys[index],
          ),
        };
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isSaving = false;
      notifyListeners();
      await _keepUnsavedOnThePhone();
    }
  }

  /// Drops this screen's drafts from the phone, when the owner changes the
  /// entry they belong to (Ketik makes a new save with a new key).
  Future<void> forgetUnsent() async {
    await _unsentDraftsStore?.forget(_idempotencyKeys);
  }

  /// Spec §5.7, #25: what failed stays on the phone with its key until it is
  /// saved, so closing the app loses nothing. Hari ini is pinned to its day,
  /// so a retry tomorrow still saves under the day the sale happened.
  Future<void> _keepUnsavedOnThePhone() async {
    final store = _unsentDraftsStore;
    if (store == null) return;
    final savedKeys = <String>[];
    final unsaved = <UnsentDraft>[];
    for (var index = 0; index < drafts.length; index++) {
      final idempotencyKey = _idempotencyKeys[index];
      if (_saveResults[index] != null) {
        savedKeys.add(idempotencyKey);
        continue;
      }
      final draft = drafts[index];
      final pinned = Draft.fromJson(draft.toJson())
        ..businessDate = draft.businessDate ?? _businessToday;
      unsaved.add(UnsentDraft(draft: pinned, idempotencyKey: idempotencyKey));
    }
    await store.forget(savedKeys);
    if (unsaved.isNotEmpty) await store.keep(unsaved);
  }

  /// The Batal toast in the 10 seconds after Simpan (§5.2): removes what
  /// this screen saved.
  Future<void> batal() async {
    _errorMessage = null;
    try {
      for (var index = 0; index < _saveResults.length; index++) {
        final saved = _saveResults[index];
        if (saved == null) continue;
        await _draftRepository.delete(saved.transaction.id);
        _saveResults[index] = null;
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      notifyListeners();
    }
  }
}

/// The chip a draft opens on: a read that heard "kemarin", or a draft kept
/// from an earlier day, already carries its date.
DateChoice _chipFor({
  required String? businessDate,
  required String businessToday,
}) {
  if (businessDate == null || businessDate == businessToday) {
    return DateChoice.hariIni;
  }
  if (businessDate == addDaysToDate(businessToday, -1)) {
    return DateChoice.kemarin;
  }
  return DateChoice.pilihTanggal;
}

/// Calendar arithmetic on a `YYYY-MM-DD` date, done in UTC so no time zone
/// or daylight change can shift it.
String addDaysToDate(String date, int days) {
  final moved = DateTime.parse('${date}T00:00:00Z').add(Duration(days: days));
  return moved.toIso8601String().substring(0, 10);
}
