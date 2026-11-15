import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/auth_repository.dart';
import 'package:malas/main.dart';

void main() {
  testWidgets('aTypedQuestionGetsAnAnswerWithCodesFigures', (tester) async {
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
        of: find.byType(NavigationBar),
        matching: find.text('Tanya'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Apa yang paling laku?');
    await tester.tap(find.byTooltip('Kirim'));
    await tester.pumpAndSettle();

    expect(find.text('Apa yang paling laku?'), findsOneWidget);
    expect(
      find.text(
        'Paling laku minggu ini: 42 porsi (Rp 630.000) dan 30 gelas '
        '(Rp 90.000).',
      ),
      findsOneWidget,
    );
    expect(find.text('5 hari dicatat'), findsOneWidget);
  });
}
