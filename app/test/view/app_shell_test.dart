import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/auth_repository.dart';
import 'package:malas/main.dart';
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
}

int _selectedTabIndex(WidgetTester tester) {
  return tester.widget<IndexedStack>(find.byType(IndexedStack)).index!;
}
