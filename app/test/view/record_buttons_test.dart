import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/auth_repository.dart';
import 'package:malas/main.dart';
import 'package:malas/view/bicara/bicara_view.dart';
import 'package:malas/view/foto/foto_view.dart';
import 'package:malas/view/ketik/ketik_view.dart';
import 'package:malas/viewmodel/app_shell_view_model.dart';

/// §4.1: the nav mic records on tap; holding it offers Bicara, Foto, Ketik.
void main() {
  Future<void> openApp(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    await tester.pumpWidget(
      MalasApp(
        apiClient: buildApiClient(baseUrl: ''),
        scheduleReminder: (_) async {},
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder mic() => find.bySemanticsLabel('Bicara').first;

  testWidgets('tappingTheMicOpensBicara', (tester) async {
    await openApp(tester);
    await tester.tap(mic());
    await tester.pumpAndSettle();

    expect(find.byType(BicaraView), findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);
  });

  testWidgets('theMicRecordsFromAnotherTab', (tester) async {
    await openApp(tester);
    await tester.tap(find.byKey(const ValueKey(AppTab.catatan)));
    await tester.pumpAndSettle();
    await tester.tap(mic());
    await tester.pumpAndSettle();

    expect(find.byType(BicaraView), findsOneWidget);
  });

  for (final (label, screen) in [('Foto', FotoView), ('Ketik', KetikView)]) {
    testWidgets('holdingTheMicOffers$label', (tester) async {
      await openApp(tester);
      await tester.longPress(mic());
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.byType(screen), findsOneWidget);
    });
  }

  testWidgets('tutupClosesTheHoldMenu', (tester) async {
    await openApp(tester);
    await tester.longPress(mic());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    expect(find.text('Foto'), findsNothing);
  });
}
