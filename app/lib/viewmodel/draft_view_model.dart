import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/draft_repository.dart';
import '../model/draft.dart';

/// The date chip at the top of the draft screen (spec §7.3).
enum DateChoice { hariIni, kemarin, pilihTanggal }

/// The draft screen: the owner checks every draft from one read, fixes what
/// is wrong, and saves them all with Simpan (spec §7.3).
class DraftViewModel extends ChangeNotifier {
  DraftViewModel({
    required this._draftRepository,
    required this._businessToday,
    required this.drafts,
    this.warnings = const [],
  }) : _idempotencyKeys = [for (final _ in drafts) generateIdempotencyKey()],
       _saveResults = List<SaveResult?>.filled(drafts.length, null);

  final DraftRepository _draftRepository;

  /// Today's business date as the server computed it (from `GET /home`).
  /// Kemarin is counted from this, never from the phone's clock.
  final String _businessToday;

  final List<Draft> drafts;
  final List<ReadWarning> warnings;

  /// One key per draft, made when the draft opens, so every retry of its
  /// Simpan reuses it and the server can't record it twice.
  final List<String> _idempotencyKeys;
  final List<SaveResult?> _saveResults;

  DateChoice _dateChoice = DateChoice.hariIni;
  bool _isSaving = false;
  String? _errorMessage;

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
        _saveResults[index] = await _draftRepository.save(
          drafts[index],
          idempotencyKey: _idempotencyKeys[index],
        );
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
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

/// Calendar arithmetic on a `YYYY-MM-DD` date, done in UTC so no time zone
/// or daylight change can shift it.
String addDaysToDate(String date, int days) {
  final moved = DateTime.parse('${date}T00:00:00Z').add(Duration(days: days));
  return moved.toIso8601String().substring(0, 10);
}
