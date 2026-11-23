import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/auth_repository.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/transaction_repository.dart';
import 'package:malas/main.dart';
import 'package:malas/model/draft.dart';
import 'package:malas/view/catatan/piutang_utang_view.dart';
import 'package:malas/view/draft/draft_view.dart';
import 'package:malas/viewmodel/draft_view_model.dart';
import 'package:provider/provider.dart';

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
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Catatan'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('catatanListsEntriesUnderTheirDates', (tester) async {
    await openCatatan(tester);

    expect(find.text('Min, 15 Nov'), findsOneWidget);
    expect(find.text('Sab, 14 Nov'), findsOneWidget);
    expect(find.text('Diubah 2x'), findsOneWidget);
    expect(find.text('Belum lunas Rp 30.000'), findsOneWidget);
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

  testWidgets('piutangUtangShowsKembalikanUnderUtang', (tester) async {
    await openCatatan(tester);

    await tester.tap(find.text('Piutang/Utang'));
    await tester.pumpAndSettle();
    expect(find.text('Pak Budi'), findsOneWidget);

    await tester.tap(find.textContaining('Utang Rp'));
    await tester.pumpAndSettle();
    expect(find.text('Kembalikan Rp 50.000'), findsOneWidget);
  });

  testWidgets('anAnalisisRowOpensCatatanNarrowedToIt', (tester) async {
    await openCatatan(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Analisis'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Sewa'), 100);
    await tester.ensureVisible(find.text('Sewa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sewa'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Sewa'), findsOneWidget);
  });

  testWidgets('theBerandaPiutangCardOpensPiutangUtang', (tester) async {
    await openCatatan(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Beranda'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Piutang Rp 240.000'));
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
