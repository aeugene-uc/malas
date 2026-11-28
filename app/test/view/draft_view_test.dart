import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/draft_repository.dart';
import 'package:malas/data/unsent_drafts_store.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/draft.dart';
import 'package:malas/view/draft/draft_view.dart';
import 'package:malas/viewmodel/draft_view_model.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('showsEveryDraftWithItsWarningsAndAnEmptyTotal', (tester) async {
    await _openDraftFromHost(tester, _RecordingAdapter());

    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
    expect(find.text('Masuk · Pak Budi'), findsOneWidget);
    expect(find.bySemanticsLabel('+Rp 180.000'), findsWidgets);
    expect(find.text('Es teh'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Tanpa barang'), findsOneWidget);
    expect(find.text('Kurang jelas, cek lagi'), findsOneWidget);
    expect(find.text('Belum dibayar'), findsOneWidget);
  });

  testWidgets('editingALineTotalUpdatesTheDraftTotal', (tester) async {
    await _openDraftFromHost(tester, _RecordingAdapter());

    await tester.tap(find.text('Es teh'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Total'), '75.000');
    await tester.tap(find.text('Pakai'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('+Rp 255.000'), findsOneWidget);
    expect(find.bySemanticsLabel('+Rp 75.000'), findsOneWidget);
  });

  testWidgets('simpanSavesThenBatalDeletesWhatWasSaved', (tester) async {
    final adapter = _RecordingAdapter();
    var changeCount = 0;
    await _openDraftFromHost(tester, adapter, onChanged: () => changeCount++);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(adapter.savedCount, 3);
    expect(find.byType(DraftView), findsNothing);
    expect(find.text('Tersimpan'), findsOneWidget);
    expect(changeCount, 1);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(adapter.deletedCount, 3);
    expect(changeCount, 2);
  });

  testWidgets('tersimpanClosesByItselfAfterTenSeconds', (tester) async {
    final adapter = _RecordingAdapter();
    await _openDraftFromHost(tester, adapter);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();

    expect(find.text('Tersimpan'), findsNothing);
    expect(adapter.deletedCount, 0);
  });

  testWidgets('aFailedSimpanKeepsTheDraftAndOffersCobaLagi', (tester) async {
    final adapter = _RecordingAdapter()..isSaveFailing = true;
    await _openDraftFromHost(tester, adapter);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.byType(DraftView), findsOneWidget);
    expect(find.text('Tidak ada koneksi'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('aReturDraftReadsReturNotBelumDibayar', (tester) async {
    await _openDraftFromHost(tester, _RecordingAdapter(), drafts: [_retur()]);

    expect(find.text('Retur'), findsOneWidget);
    expect(find.text('Belum dibayar'), findsNothing);
    expect(find.bySemanticsLabel('\u2212Rp 30.000'), findsWidgets);
  });

  testWidgets('ubahBarisShowsDotsAndKeepsAReturLineNegative', (tester) async {
    await _openDraftFromHost(tester, _RecordingAdapter(), drafts: [_retur()]);

    await tester.tap(find.text('Nasi goreng'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '15.000'), findsOneWidget);
    expect(find.widgetWithText(TextField, '30.000'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '30.000'), '45000');
    expect(find.widgetWithText(TextField, '45.000'), findsOneWidget);
    await tester.tap(find.text('Pakai'));
    await tester.pumpAndSettle();

    final draftScreen = tester.element(find.byType(DraftView));
    expect(draftScreen.read<DraftViewModel>().drafts.single.total, -45000);
  });

  group('input parsing', () {
    test('parseRupiahInputReadsWholeRupiah', () {
      expect(parseRupiahInput('Rp 12.500'), 12500);
      expect(parseRupiahInput('12500'), 12500);
      expect(parseRupiahInput('  '), isNull);
    });

    test('parseQuantityInputReadsACommaAsTheDecimalMark', () {
      expect(parseQuantityInput('0,5'), '0.5');
      expect(parseQuantityInput('2'), '2');
      expect(parseQuantityInput('dua'), isNull);
      expect(parseQuantityInput(''), isNull);
    });

    test('formatBusinessDatePadsMonthAndDay', () {
      expect(formatBusinessDate(DateTime(2026, 3, 7)), '2026-03-07');
    });
  });
}

Future<void> _openDraftFromHost(
  WidgetTester tester,
  _RecordingAdapter adapter, {
  VoidCallback? onChanged,
  List<Draft>? drafts,
}) async {
  // Tall enough that all three drafts are built, not scrolled off.
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
    ..httpClientAdapter = adapter;
  final readResult = AiReadResult.fromJson(
    mockBodiesByRoute['POST /ai/read']! as Map<String, Object?>,
  );
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider(create: (_) => DraftRepository(ApiClient(dio))),
        Provider(
          create: (_) =>
              UnsentDraftsStore(const FlutterSecureStorage())
                ..storeId = 'store-1',
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openDraftScreen(
                context,
                drafts: drafts ?? readResult.drafts,
                warnings: drafts == null ? readResult.warnings : const [],
                businessToday: '2026-11-11',
                onChanged: onChanged ?? () {},
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

/// The mock adapter, counting saves and deletes, and able to drop every
/// save the way a lost connection does.
class _RecordingAdapter implements HttpClientAdapter {
  final MockApiAdapter _mock = MockApiAdapter(bodiesByRoute: mockBodiesByRoute);
  int savedCount = 0;
  int deletedCount = 0;
  bool isSaveFailing = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final isSave =
        options.method == 'POST' && options.path.endsWith('/transactions');
    if (isSave && isSaveFailing) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    if (isSave) savedCount++;
    if (options.method == 'DELETE') deletedCount++;
    return _mock.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

/// Nasi goreng taken back: 2 porsi at Rp 15.000, linked to trx-1.
Draft _retur() {
  return Draft.fromJson(const {
    'direction': 'IN',
    'total': -30000,
    'personId': null,
    'personName': null,
    'dueDate': null,
    'source': 'TYPED',
    'inputId': null,
    'note': null,
    'linkedTransactionId': 'trx-1',
    'lines': [
      {
        'itemId': 'item-1',
        'itemName': 'Nasi goreng',
        'categoryId': 'cat-1',
        'quantity': '-2',
        'unit': 'porsi',
        'unitPrice': 15000,
        'lineTotal': -30000,
      },
    ],
    'payments': <Object?>[],
  });
}
