import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/draft_repository.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/unsent_drafts_store.dart';
import 'package:malas/model/draft.dart';
import 'package:malas/viewmodel/draft_view_model.dart';

void main() {
  late _ScriptedAdapter adapter;
  late DraftViewModel viewModel;

  setUp(() {
    adapter = _ScriptedAdapter();
    final readResult = AiReadResult.fromJson(
      mockBodiesByRoute['POST /ai/read']! as Map<String, Object?>,
    );
    viewModel = DraftViewModel(
      draftRepository: DraftRepository(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
        ),
      ),
      businessToday: '2026-11-01',
      drafts: readResult.drafts,
      warnings: readResult.warnings,
    );
  });

  test('kemarinCountsBackFromTheServersTodayAcrossAMonth', () {
    viewModel.selectDate(DateChoice.kemarin);

    expect(viewModel.businessDate, '2026-10-31');
    expect(
      viewModel.drafts.every((draft) => draft.businessDate == '2026-10-31'),
      isTrue,
    );
  });

  test('hariIniSendsNoDate', () {
    viewModel.selectDate(DateChoice.kemarin);
    viewModel.selectDate(DateChoice.hariIni);

    expect(viewModel.businessDate, isNull);
  });

  test('editLineUpdatesTheProvisionalTotal', () {
    viewModel.editLine(
      draftIndex: 0,
      lineIndex: 1,
      edit: (line) => line.lineTotal = 75000,
    );

    expect(viewModel.drafts.first.total, 255000);
  });

  test('warningsForPicksTheLineItBelongsTo', () {
    expect(
      viewModel.warningsFor(draftIndex: 0, lineIndex: 1).single.code,
      'UNCLEAR_READ',
    );
    expect(viewModel.warningsFor(draftIndex: 0, lineIndex: 0), isEmpty);
  });

  test('simpanSavesEveryDraftEachWithItsOwnKey', () async {
    await viewModel.simpan();

    expect(viewModel.isAllSaved, isTrue);
    expect(adapter.saveKeys, hasLength(3));
    expect(adapter.saveKeys.toSet(), hasLength(3));
  });

  test('cobaLagiRetriesOnlyUnsavedDraftsWithTheSameKeys', () async {
    adapter.failSaveNumber = 2;

    await viewModel.simpan();

    expect(viewModel.isAllSaved, isFalse);
    expect(viewModel.errorMessage, 'Tidak ada koneksi');
    final keysOfFirstTry = List.of(adapter.saveKeys);

    await viewModel.simpan();

    expect(viewModel.isAllSaved, isTrue);
    expect(viewModel.errorMessage, isNull);
    expect(adapter.saveKeys.skip(keysOfFirstTry.length), [
      keysOfFirstTry[1],
      isNot(keysOfFirstTry[0]),
    ]);
  });

  test('opensOnTheChipForTheDraftsOwnDate', () {
    DraftViewModel openOn(String? businessDate) {
      final drafts = _readDrafts();
      for (final draft in drafts) {
        draft.businessDate = businessDate;
      }
      return _buildViewModel(adapter, drafts: drafts);
    }

    expect(openOn(null).dateChoice, DateChoice.hariIni);
    expect(openOn('2026-11-01').dateChoice, DateChoice.hariIni);
    expect(openOn('2026-10-31').dateChoice, DateChoice.kemarin);
    expect(openOn('2026-10-20').dateChoice, DateChoice.pilihTanggal);
  });

  group('kept on the phone (#25)', () {
    late UnsentDraftsStore store;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      store = UnsentDraftsStore(const FlutterSecureStorage())
        ..storeId = 'store-1';
    });

    test('aFailedSimpanKeepsTheUnsavedDraftsWithTheirKeysAndDay', () async {
      final keptViewModel = _buildViewModel(adapter, store: store);
      adapter.failSaveNumber = 2;

      await keptViewModel.simpan();

      final kept = await store.load();
      expect(kept, hasLength(2));
      expect(kept.first.idempotencyKey, adapter.saveKeys[1]);
      expect(kept.first.draft.total, 25000);
      // Hari ini is pinned, so a retry tomorrow saves under today.
      expect(
        kept.every((unsent) => unsent.draft.businessDate == '2026-11-01'),
        isTrue,
      );
    });

    test('cobaLagiAfterReopeningSendsTheKeptKeysAndClearsThePhone', () async {
      const keys = ['key-a', 'key-b', 'key-c'];
      final drafts = _readDrafts();
      await store.keep([
        for (var index = 0; index < keys.length; index++)
          UnsentDraft(draft: drafts[index], idempotencyKey: keys[index]),
      ]);
      final reopened = _buildViewModel(
        adapter,
        drafts: drafts,
        store: store,
        idempotencyKeys: keys,
        isUnsent: true,
      );

      expect(reopened.errorMessage, DraftViewModel.unsentMessage);

      await reopened.simpan();

      expect(adapter.saveKeys, keys);
      expect(reopened.errorMessage, isNull);
      expect(await store.load(), isEmpty);
    });
  });

  test('batalDeletesWhatWasSaved', () async {
    await viewModel.simpan();

    await viewModel.batal();

    expect(adapter.deletedPaths, hasLength(3));
    expect(viewModel.saveResults, isEmpty);
  });
}

List<Draft> _readDrafts() {
  return AiReadResult.fromJson(
    mockBodiesByRoute['POST /ai/read']! as Map<String, Object?>,
  ).drafts;
}

DraftViewModel _buildViewModel(
  _ScriptedAdapter adapter, {
  List<Draft>? drafts,
  UnsentDraftsStore? store,
  List<String>? idempotencyKeys,
  bool isUnsent = false,
}) {
  return DraftViewModel(
    draftRepository: DraftRepository(
      ApiClient(
        Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
      ),
    ),
    businessToday: '2026-11-01',
    drafts: drafts ?? _readDrafts(),
    unsentDraftsStore: store,
    idempotencyKeys: idempotencyKeys,
    isUnsent: isUnsent,
  );
}

/// Answers saves with the mock body, and can fail one numbered save with no
/// response, the way a dropped connection looks.
class _ScriptedAdapter implements HttpClientAdapter {
  final List<String> saveKeys = [];
  final List<String> deletedPaths = [];
  int? failSaveNumber;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'DELETE') {
      deletedPaths.add(options.path);
      return _json(200, {'ok': true});
    }
    saveKeys.add(options.headers['Idempotency-Key'] as String);
    if (saveKeys.length == failSaveNumber) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return _json(201, mockBodiesByRoute['POST /transactions']!);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int statusCode, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
