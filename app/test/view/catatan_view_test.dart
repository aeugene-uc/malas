import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/auth_repository.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/mock_transaction_store.dart';
import 'package:malas/data/transaction_repository.dart';
import 'package:malas/main.dart';
import 'package:malas/model/draft.dart';
import 'package:malas/view/catatan/piutang_utang_view.dart';
import 'package:malas/view/draft/draft_view.dart';
import 'package:malas/view/theme/lip.dart';
import 'package:malas/view/theme/parts.dart';
import 'package:malas/viewmodel/draft_view_model.dart';
import 'package:provider/provider.dart';

import '../support/recording_adapter.dart';

import 'package:malas/viewmodel/app_shell_view_model.dart';

void main() {
  Future<void> openCatatan(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MalasApp(
        apiClient: buildApiClient(baseUrl: ''),
        scheduleReminder: (_) async {},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey(AppTab.catatan)));
    await tester.pumpAndSettle();
  }

  testWidgets('catatanLoadsAgainEachTimeItsTabOpens', (tester) async {
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    final adapter = RecordingAdapter(
      bodiesByRoute: {...mockBodiesByRoute, ...MockTransactionStore().routes},
    );
    await tester.pumpWidget(
      MalasApp(
        apiClient: ApiClient(
          Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
        ),
        scheduleReminder: (_) async {},
      ),
    );
    await tester.pumpAndSettle();
    int countListLoads() =>
        adapter.requests.where((r) => r.path == '/transactions').length;
    Future<void> openTab(String label) async {
      await tester.tap(
        find.byKey(
          ValueKey(AppTab.values.firstWhere((tab) => tab.label == label)),
        ),
      );
      await tester.pumpAndSettle();
    }

    await openTab('Catatan');
    final loadsOnFirstOpen = countListLoads();
    await openTab('Beranda');
    await openTab('Catatan');

    expect(countListLoads(), loadsOnFirstOpen + 1);
  });

  testWidgets('berandaLoadsAgainEachTimeItsTabOpens', (tester) async {
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    final adapter = RecordingAdapter(
      bodiesByRoute: {...mockBodiesByRoute, ...MockTransactionStore().routes},
    );
    await tester.pumpWidget(
      MalasApp(
        apiClient: ApiClient(
          Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
        ),
        scheduleReminder: (_) async {},
      ),
    );
    await tester.pumpAndSettle();
    int countHomeLoads() =>
        adapter.requests.where((r) => r.path == '/home').length;
    Future<void> openTab(String label) async {
      await tester.tap(
        find.byKey(
          ValueKey(AppTab.values.firstWhere((tab) => tab.label == label)),
        ),
      );
      await tester.pumpAndSettle();
    }

    final loadsAtStart = countHomeLoads();
    await openTab('Catatan');
    await openTab('Beranda');

    expect(countHomeLoads(), loadsAtStart + 1);
  });

  testWidgets('catatanListsEntriesUnderTheirDates', (tester) async {
    await openCatatan(tester);

    expect(find.text('Min, 15 Nov'), findsOneWidget);
    expect(find.text('Sab, 14 Nov'), findsOneWidget);
    expect(find.text('Diubah 2x'), findsOneWidget);
    expect(find.text('Sisa Rp 30.000'), findsOneWidget);
  });

  testWidgets('clearingTheSearchShowsEveryEntryAgain', (tester) async {
    await openCatatan(tester);

    await tester.enterText(find.byType(TextField), 'gas');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Pak Budi'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('Pak Budi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'gas');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hapus pencarian'));
    await tester.pumpAndSettle();
    expect(find.text('Pak Budi'), findsOneWidget);
  });

  testWidgets('swipingAnEntryAwayOffersBatal', (tester) async {
    await openCatatan(tester);

    await tester.drag(find.text('Gas'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    // The mock adapter answers DELETE on real async, which the test clock
    // does not run.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Dihapus'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Gas'), findsNothing);
  });

  Future<Draft> openCopyOfGas(WidgetTester tester, String button) async {
    await openCatatan(tester);
    await tester.tap(find.text('Gas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    // The mock adapter answers on real async, which the test clock does not
    // run.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    final draftScreen = tester.element(find.byType(DraftView));
    return draftScreen.read<DraftViewModel>().drafts.single;
  }

  testWidgets('ulangiOpensTheEntryAsAPaidDraftDatedToday', (tester) async {
    final draft = await openCopyOfGas(tester, 'Ulangi');

    expect(draft.total, 25000);
    expect(draft.businessDate, '2026-11-11');
    expect(draft.payments.single.amount, 25000);
    expect(draft.linkedTransactionId, isNull);
  });

  testWidgets('returOpensTheEntryTakenBackAndLinkedToIt', (tester) async {
    final draft = await openCopyOfGas(tester, 'Retur');

    expect(draft.total, -25000);
    expect(draft.lines.single.lineTotal, -25000);
    expect(draft.payments, isEmpty);
    expect(draft.linkedTransactionId, 'trx-2');
  });

  /// Ubah on Gas, its total changed to Rp 30.000, then Simpan.
  Future<void> editGasTo30000(WidgetTester tester) async {
    final draft = await openCopyOfGas(tester, 'Ubah');
    expect(draft.businessDate, '2026-11-15');
    // Gas is from 15 Nov and the mock's today is 11 Nov.
    expect(
      tester.element(find.byType(DraftView)).read<DraftViewModel>().dateChoice,
      DateChoice.pilihTanggal,
    );
    tester
        .element(find.byType(DraftView))
        .read<DraftViewModel>()
        .editLine(
          draftIndex: 0,
          lineIndex: 0,
          edit: (line) => line.lineTotal = 30000,
        );
    await tester.tap(find.text('Simpan'));
    // The save, then the list's reload.
    for (var step = 0; step < 2; step++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('ubahSavesOverTheEntryWithoutBatal', (tester) async {
    await editGasTo30000(tester);

    expect(find.text('Diubah 1x'), findsOneWidget);
    expect(find.bySemanticsLabel('\u2212Rp 30.000'), findsOneWidget);
    expect(find.text('Batal'), findsNothing);
  });

  testWidgets('diubahListsTheEntryAsItWasBefore', (tester) async {
    await editGasTo30000(tester);

    await tester.tap(find.text('Gas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diubah 1x').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(RowsCard),
        matching: find.bySemanticsLabel('Rp 25.000'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('piutangUtangShowsKembalikanUnderUtang', (tester) async {
    await openCatatan(tester);

    await tester.tap(find.text('Piutang/Utang'));
    await tester.pumpAndSettle();
    expect(find.text('Pak Budi'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedSelector),
        matching: find.text('Utang'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kembalikan'), findsOneWidget);
    expect(find.bySemanticsLabel('Rp 50.000'), findsOneWidget);
  });

  testWidgets('bayarAmountShowsThousandsDots', (tester) async {
    await openCatatan(tester);
    await tester.tap(find.text('Piutang/Utang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pak Budi'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(LipButton, 'Bayar'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '30.000'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1200000');
    expect(find.widgetWithText(TextField, '1.200.000'), findsOneWidget);
  });

  testWidgets('anAnalisisRowOpensCatatanNarrowedToIt', (tester) async {
    await openCatatan(tester);
    await tester.tap(find.byKey(const ValueKey(AppTab.analisis)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Sewa'), 100);
    await tester.ensureVisible(find.text('Sewa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sewa'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(LipPressable, 'Sewa'), findsOneWidget);
  });

  testWidgets('theBerandaPiutangCardOpensPiutangUtang', (tester) async {
    await openCatatan(tester);
    await tester.tap(find.byKey(const ValueKey(AppTab.beranda)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Piutang'));
    await tester.pumpAndSettle();

    expect(find.byType(PiutangUtangView), findsOneWidget);
  });

  test('theReminderTextNamesThePersonAmountAndDueDate', () async {
    final repository = TransactionRepository(
      ApiClient(
        Dio(
          BaseOptions(baseUrl: 'http://mock'),
        )..httpClientAdapter = MockApiAdapter(bodiesByRoute: mockBodiesByRoute),
      ),
    );
    final budi = (await repository.fetchPiutang()).single;

    expect(
      buildReminderText(personName: 'Pak Budi', transaction: budi),
      'Halo Pak Budi, mengingatkan sisa pembayaran Rp 30.000 untuk catatan '
      'Sab, 14 Nov, jatuh tempo Jum, 20 Nov. Terima kasih.',
    );
  });
}
