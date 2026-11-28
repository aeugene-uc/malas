import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/auth_repository.dart';
import 'package:malas/main.dart';
import 'package:malas/viewmodel/app_shell_view_model.dart';

void main() {
  testWidgets('theAnalisisTabShowsTheSummaryAndBothLists', (tester) async {
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

    await tester.tap(find.byKey(const ValueKey(AppTab.analisis)));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('+Rp 8.640.000'), findsOneWidget);
    expect(find.text('Hari dicatat'), findsOneWidget);
    expect(find.text('10 dari 15'), findsOneWidget);
    expect(find.text('Masuk per barang'), findsOneWidget);
    expect(find.text('Nasi goreng'), findsOneWidget);
  });
}
