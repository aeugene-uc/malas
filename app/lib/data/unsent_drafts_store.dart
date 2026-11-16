import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../model/draft.dart';

/// Drafts whose Simpan failed, kept on the phone so an entry survives the app
/// being closed while the owner waits for signal (spec §5.7, #25). Each keeps
/// its Idempotency-Key, so Coba lagi on the next open can't record it twice.
/// Nothing is sent on its own: there is no outbox and no background sync.
class UnsentDraftsStore {
  UnsentDraftsStore(this._secureStorage);

  static const String storageKey = 'unsentDrafts';

  final FlutterSecureStorage _secureStorage;

  /// The signed-in store. Drafts are kept under it and only its own come
  /// back, so an owner signing in after another on a shared phone (Q2) is
  /// never offered, or able to save, the other store's entries.
  String? storeId;

  /// Changes run one after another, so Ketik forgetting a changed entry
  /// can't race the next failed save and bring the old one back.
  Future<void> _lastChange = Future.value();

  Future<List<UnsentDraft>> load() async {
    return [
      for (final draft in await _loadAllStores())
        if (draft.storeId == storeId) draft,
    ];
  }

  /// Adds [drafts] under the signed-in store, replacing any kept under the
  /// same key.
  Future<void> keep(List<UnsentDraft> drafts) {
    final newKeys = {for (final draft in drafts) draft.idempotencyKey};
    final storeId = this.storeId;
    return _change((kept) => [
      for (final draft in kept)
        if (!newKeys.contains(draft.idempotencyKey)) draft,
      for (final draft in drafts)
        UnsentDraft(
          draft: draft.draft,
          idempotencyKey: draft.idempotencyKey,
          storeId: storeId,
        ),
    ]);
  }

  /// Drops the drafts with these keys, once they are saved or replaced.
  Future<void> forget(Iterable<String> idempotencyKeys) {
    final keys = idempotencyKeys.toSet();
    return _change((kept) => [
      for (final draft in kept)
        if (!keys.contains(draft.idempotencyKey)) draft,
    ]);
  }

  Future<void> _change(
    List<UnsentDraft> Function(List<UnsentDraft> kept) update,
  ) {
    // A failed change already reached its own caller; the next one still runs.
    final change = _lastChange
        .catchError((Object _) {})
        .then((_) async => _write(update(await _loadAllStores())));
    _lastChange = change;
    return change;
  }

  Future<List<UnsentDraft>> _loadAllStores() async {
    final stored = await _secureStorage.read(key: storageKey);
    if (stored == null) return const [];
    return [
      for (final json in jsonDecode(stored) as List<Object?>)
        UnsentDraft.fromJson(json as Map<String, Object?>),
    ];
  }

  Future<void> _write(List<UnsentDraft> drafts) async {
    if (drafts.isEmpty) {
      await _secureStorage.delete(key: storageKey);
      return;
    }
    await _secureStorage.write(
      key: storageKey,
      value: jsonEncode([for (final draft in drafts) draft.toJson()]),
    );
  }
}

class UnsentDraft {
  const UnsentDraft({
    required this.draft,
    required this.idempotencyKey,
    this.storeId,
  });

  factory UnsentDraft.fromJson(Map<String, Object?> json) {
    return UnsentDraft(
      draft: Draft.fromJson(json['draft'] as Map<String, Object?>),
      idempotencyKey: json['idempotencyKey'] as String,
      storeId: json['storeId'] as String?,
    );
  }

  final Draft draft;
  final String idempotencyKey;

  /// Set by [UnsentDraftsStore.keep]; a draft kept before stores were
  /// recorded has none and never comes back.
  final String? storeId;

  Map<String, Object?> toJson() {
    return {
      'draft': draft.toJson(),
      'idempotencyKey': idempotencyKey,
      'storeId': storeId,
    };
  }
}
