import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/auth_repository.dart';
import 'package:malas/main.dart';
import 'package:malas/view/bicara/bicara_view.dart';
import 'package:malas/view/foto/foto_view.dart';

void main() {
  Future<void> tapRecordButton(WidgetTester tester, String label) async {
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    await tester.pumpWidget(
      MalasApp(
        apiClient: buildApiClient(baseUrl: ''),
        scheduleReminder: (_) async {},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('bicaraButtonOpensTheBicaraScreen', (tester) async {
    await tapRecordButton(tester, 'Bicara');

    expect(find.byType(BicaraView), findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);
  });

  testWidgets('fotoButtonOpensTheFotoScreen', (tester) async {
    await tapRecordButton(tester, 'Foto');

    expect(find.byType(FotoView), findsOneWidget);
    expect(find.text('Kamera'), findsOneWidget);
  });
}
