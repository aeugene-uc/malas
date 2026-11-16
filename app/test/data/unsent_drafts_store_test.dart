import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/unsent_drafts_store.dart';
import 'package:malas/model/draft.dart';

void main() {
  late UnsentDraftsStore store;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    store = UnsentDraftsStore(const FlutterSecureStorage());
  });

  test('readsBackKeptDraftsWithTheirKeysAndDate', () async {
    await store.keep([
      _unsent('key-1', total: 180000),
      _unsent('key-2', total: 25000),
    ]);

    final kept = await store.load();

    expect([for (final unsent in kept) unsent.idempotencyKey], [
      'key-1',
      'key-2',
    ]);
    expect(kept.first.draft.total, 180000);
    expect(kept.first.draft.lines.first.quantity, '12');
    expect(kept.first.draft.businessDate, '2026-11-10');
  });

  test('keepingTheSameKeyAgainReplacesIt', () async {
    await store.keep([_unsent('key-1', total: 180000)]);
    await store.keep([_unsent('key-1', total: 190000)]);

    final kept = await store.load();

    expect(kept, hasLength(1));
    expect(kept.single.draft.total, 190000);
  });

  test('forgettingTheLastDraftLeavesNothingOnThePhone', () async {
    await store.keep([
      _unsent('key-1', total: 180000),
      _unsent('key-2', total: 25000),
    ]);

    await store.forget(['key-1']);

    expect([for (final unsent in await store.load()) unsent.idempotencyKey], [
      'key-2',
    ]);

    await store.forget(['key-2']);

    expect(
      await const FlutterSecureStorage().read(
        key: UnsentDraftsStore.storageKey,
      ),
      isNull,
    );
  });

  test('aForgetAndAKeepStartedTogetherBothLand', () async {
    await store.keep([_unsent('key-old', total: 50000)]);

    // Not awaited one by one, the way Ketik drops a changed amount just
    // before its next Simpan fails.
    await Future.wait([
      store.forget(['key-old']),
      store.keep([_unsent('key-new', total: 60000)]),
    ]);

    expect([for (final unsent in await store.load()) unsent.idempotencyKey], [
      'key-new',
    ]);
  });
}

UnsentDraft _unsent(String idempotencyKey, {required int total}) {
  final readBody = mockBodiesByRoute['POST /ai/read']! as Map<String, Object?>;
  final draftJson =
      (readBody['drafts']! as List<Object?>).first! as Map<String, Object?>;
  final draft = Draft.fromJson(draftJson)
    ..businessDate = '2026-11-10'
    ..total = total;
  return UnsentDraft(draft: draft, idempotencyKey: idempotencyKey);
}
