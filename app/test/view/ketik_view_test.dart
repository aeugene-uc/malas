import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/draft_repository.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/store_repository.dart';
import 'package:malas/data/unsent_drafts_store.dart';
import 'package:malas/view/ketik/ketik_view.dart';
import 'package:malas/view/theme/lip.dart';
import 'package:provider/provider.dart';

import '../support/signal_adapter.dart';

void main() {
  testWidgets('aTypedAmountSavesAtOnceWithBatal', (tester) async {
    var changeCount = 0;
    final apiClient = ApiClient(
      Dio(BaseOptions(baseUrl: 'http://mock'))
        ..httpClientAdapter = MockApiAdapter(bodiesByRoute: mockBodiesByRoute),
    );
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => StoreRepository(apiClient)),
          Provider(create: (_) => DraftRepository(apiClient)),
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
                onPressed: () => openKetik(
                  context,
                  businessToday: '2026-11-16',
                  onChanged: () => changeCount++,
                ),
                child: const Text('ketik'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ketik'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(LipPressable, 'Penjualan'), findsOneWidget);
    expect(
      tester
          .widget<LipButton>(find.widgetWithText(LipButton, 'Simpan'))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), '1200000');
    await tester.pump();

    expect(find.text('1.200.000'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Tersimpan'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(changeCount, 1);
  });

  testWidgets('cobaLagiFetchesCategoriesThatNeverArrived', (tester) async {
    final adapter = SignalAdapter()..isOffline = true;
    final apiClient = ApiClient(
      Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
    );
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => StoreRepository(apiClient)),
          Provider(create: (_) => DraftRepository(apiClient)),
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
                onPressed: () => openKetik(
                  context,
                  businessToday: '2026-11-16',
                  onChanged: () {},
                ),
                child: const Text('ketik'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ketik'));
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada koneksi'), findsOneWidget);
    expect(find.widgetWithText(LipPressable, 'Penjualan'), findsNothing);

    adapter.isOffline = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada koneksi'), findsNothing);
    expect(find.widgetWithText(LipPressable, 'Penjualan'), findsOneWidget);
  });
}
