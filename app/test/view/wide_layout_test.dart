import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/auth_repository.dart';
import 'package:malas/main.dart';
import 'package:malas/view/catatan/entry_detail_sheet.dart';
import 'package:malas/view/theme/tokens.dart';
import 'package:malas/viewmodel/app_shell_view_model.dart';

import '../support/app_fonts.dart';

/// F16 (#55): tablets and an open Fold, 600 dp and wider.
void main() {
  setUpAll(loadAppFonts);

  Future<void> openAt(WidgetTester tester, {required double width}) async {
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    tester.view.physicalSize = Size(width * 2, 900 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MalasApp(
        apiClient: buildApiClient(baseUrl: ''),
        scheduleReminder: (_) async {},
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, AppTab tab) async {
    await tester.tap(find.byKey(ValueKey(tab)));
    await tester.pumpAndSettle();
  }

  bool isHighlighted(WidgetTester tester, String rowTitle) {
    final backgrounds = tester.widgetList<ColoredBox>(
      find.ancestor(of: find.text(rowTitle), matching: find.byType(ColoredBox)),
    );
    return backgrounds.any((box) => box.color == MalasColors.bgSelected);
  }

  testWidgets('wideCatatanShowsTheNewestEntryBesideTheList', (tester) async {
    await openAt(tester, width: 673);
    await openTab(tester, AppTab.catatan);

    expect(find.byType(EntryDetailPane), findsOneWidget);
    expect(find.text('Ubah'), findsOneWidget);
    // The pane starts at the top, level with the list, not floating midway.
    expect(tester.getTopLeft(find.byType(EntryDetailPane)).dy, 0);
    expect(isHighlighted(tester, 'Nasi goreng, Es teh'), isTrue);
  });

  testWidgets('tappingARowOnAWideScreenShowsItInThePaneNotASheet', (
    tester,
  ) async {
    await openAt(tester, width: 673);
    await openTab(tester, AppTab.catatan);

    await tester.tap(find.text('Gas'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    // The row and the pane's title.
    expect(find.text('Gas'), findsNWidgets(2));
    expect(isHighlighted(tester, 'Gas'), isTrue);
    expect(isHighlighted(tester, 'Nasi goreng, Es teh'), isFalse);
  });

  testWidgets('aPhoneStillOpensTheEntryInASheet', (tester) async {
    await openAt(tester, width: 360);
    await openTab(tester, AppTab.catatan);

    expect(find.byType(EntryDetailPane), findsNothing);
    await tester.tap(find.text('Gas'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
  });

  for (final width in [600.0, 673.0, 1024.0]) {
    testWidgets('everyTabFitsAt${width.toInt()}dp', (tester) async {
      await openAt(tester, width: width);
      for (final tab in AppTab.values) {
        await openTab(tester, tab);
        expect(tester.takeException(), isNull, reason: '$tab');
      }
    });
  }
}
