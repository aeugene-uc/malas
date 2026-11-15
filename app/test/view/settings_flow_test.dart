import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/auth_repository.dart';
import 'package:malas/main.dart';
import 'package:malas/view/beranda/beranda_view.dart';
import 'package:malas/view/first_run/sign_in_view.dart';
import 'package:malas/view/settings/items_view.dart';
import 'package:malas/view/settings/settings_view.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
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
    await tester.tap(find.text('Warung Bu Sari'));
    await tester.pumpAndSettle();
  }

  testWidgets('theBusinessNameOnBerandaOpensSettings', (tester) async {
    await openSettings(tester);

    expect(find.byType(SettingsView), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('simpanAfterAnEditGoesBackToBeranda', (tester) async {
    await openSettings(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Jum'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsView), findsNothing);
    expect(find.byType(BerandaView), findsOneWidget);
  });

  testWidgets('barangDanSatuanListsTheItems', (tester) async {
    await openSettings(tester);

    await tester.ensureVisible(find.text('Barang dan satuan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barang dan satuan'));
    await tester.pumpAndSettle();

    expect(find.byType(ItemsView), findsOneWidget);
    expect(find.text('Nasi goreng'), findsOneWidget);
    expect(find.text('harga belum ada'), findsOneWidget);
  });

  Future<void> tapKeluar(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Keluar'), 100);
    await tester.ensureVisible(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
  }

  testWidgets('keluarAsksFirstAndBatalStaysSignedIn', (tester) async {
    await openSettings(tester);

    await tapKeluar(tester);
    expect(find.text('Keluar dari akun?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsView), findsOneWidget);
    expect(
      await const FlutterSecureStorage().read(key: AuthRepository.tokenKey),
      isNotNull,
    );
  });

  testWidgets('confirmingKeluarGoesBackToSignIn', (tester) async {
    await openSettings(tester);

    await tapKeluar(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInView), findsOneWidget);
    expect(
      await const FlutterSecureStorage().read(key: AuthRepository.tokenKey),
      isNull,
    );
  });
}
