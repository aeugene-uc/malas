import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/auth_repository.dart';
import 'package:malas/main.dart';
import 'package:malas/view/ketik/ketik_view.dart';
import 'package:malas/viewmodel/app_shell_view_model.dart';

void main() {
  testWidgets('opensOnBerandaAndSwitchesTabWhenTapped', (tester) async {
    // A saved token, so the app starts signed in instead of on sign-in.
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    await tester.pumpWidget(
      MalasApp(
        apiClient: buildApiClient(baseUrl: ''),
        scheduleReminder: (_) async {},
      ),
    );
    // Beranda loads /home on open; let it finish so no request is left hanging.
    await tester.pumpAndSettle();

    expect(_selectedTabIndex(tester), 0);

    await tester.tap(find.byKey(const ValueKey(AppTab.catatan)));
    await tester.pumpAndSettle();

    expect(_selectedTabIndex(tester), 1);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
  });

  testWidgets('holdingThenSlidingOntoKetikAndLettingGoOpensKetik', (
    tester,
  ) async {
    await _openSignedIn(tester);

    final gesture = await _holdMic(tester);
    await gesture.moveTo(tester.getCenter(find.text('Ketik')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(KetikView), findsOneWidget);
  });

  testWidgets('lettingGoWithoutSlidingKeepsTheButtonsForATap', (tester) async {
    await _openSignedIn(tester);

    final gesture = await _holdMic(tester);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Foto'), findsOneWidget);
    expect(find.byType(KetikView), findsNothing);

    await tester.tap(find.text('Ketik'));
    await tester.pumpAndSettle();

    expect(find.byType(KetikView), findsOneWidget);
  });

  testWidgets('backClosesTheButtonsAndStaysInTheApp', (tester) async {
    await _openSignedIn(tester);
    final gesture = await _holdMic(tester);
    await gesture.up();
    await tester.pumpAndSettle();

    final isHandledByApp = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(isHandledByApp, isTrue);
    expect(find.text('Foto'), findsNothing);
  });
}

Future<void> _openSignedIn(WidgetTester tester) async {
  FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
  await tester.pumpWidget(
    MalasApp(
      apiClient: buildApiClient(baseUrl: ''),
      scheduleReminder: (_) async {},
    ),
  );
  await tester.pumpAndSettle();
}

/// Holds the mic until the three buttons are out, finger still down.
Future<TestGesture> _holdMic(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byTooltip('Bicara')),
  );
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
  return gesture;
}

int _selectedTabIndex(WidgetTester tester) {
  return tester.widget<IndexedStack>(find.byType(IndexedStack)).index!;
}
