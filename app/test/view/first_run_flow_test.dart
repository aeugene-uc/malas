import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/main.dart';
import 'package:malas/model/account.dart';
import 'package:malas/view/app_shell.dart';
import 'package:malas/view/first_run/first_run_view.dart';
import 'package:malas/view/first_run/sign_in_view.dart';
import 'package:malas/view/first_run/trial_sheet.dart';

void main() {
  testWidgets('daftarThenFirstRunSetupOpensBeranda', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      MalasApp(
        apiClient: buildApiClient(baseUrl: ''),
        scheduleReminder: (_) async {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SignInView), findsOneWidget);

    await tester.tap(find.text('Daftar').first);
    await tester.pumpAndSettle();
    await tester.enterText(_field('Nama'), 'Pak Budi');
    await tester.enterText(_field('Nomor HP'), '081298765432');
    await tester.enterText(_field('Kata sandi'), 'rahasia');
    await tester.tap(find.widgetWithText(FilledButton, 'Daftar'));
    await tester.pumpAndSettle();
    expect(find.byType(FirstRunView), findsOneWidget);
    expect(find.text(consentLine), findsOneWidget);

    await tester.enterText(_field('Nama usaha'), 'Warung Pak Budi');
    await tester.tap(find.text('Makanan & minuman'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setuju dan mulai'));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('masukWithASetUpStoreOpensBeranda', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      MalasApp(
        apiClient: buildApiClient(baseUrl: ''),
        scheduleReminder: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_field('Nomor HP'), '081234567890');
    await tester.enterText(_field('Kata sandi'), 'rahasia');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
  });

  for (final (buttonLabel, expectedPlan) in [
    ('Pilih Pro', Plan.pro),
    ('Lanjut Gratis', Plan.gratis),
  ]) {
    testWidgets('trialSheetReturns${expectedPlan.name}For$buttonLabel', (
      tester,
    ) async {
      Plan? chosenPlan;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => chosenPlan = await showTrialSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Rp 25.000/bulan'), findsOneWidget);

      await tester.tap(find.text(buttonLabel));
      await tester.pumpAndSettle();

      expect(chosenPlan, expectedPlan);
    });
  }
}

Finder _field(String label) => find.widgetWithText(TextField, label);
