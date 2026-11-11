import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/main.dart';

void main() {
  testWidgets('opensOnBerandaAndSwitchesTabWhenTapped', (tester) async {
    await tester.pumpWidget(MalasApp(apiClient: buildApiClient(baseUrl: '')));

    expect(_selectedTabIndex(tester), 0);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Catatan'),
      ),
    );
    await tester.pump();

    expect(_selectedTabIndex(tester), 1);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
  });
}

int _selectedTabIndex(WidgetTester tester) {
  return tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;
}
