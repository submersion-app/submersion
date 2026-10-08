import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/select_items_menu_entries.dart';

/// The overflow button of the first app bar on screen, which holds
/// "Select items" on every entity list except Media (issue #2775).
Finder get overflowMenuButton => find.byIcon(Icons.more_vert).first;

/// Enters selection mode the way a user does: opens [menu] (the first
/// overflow button by default) and chooses "Select items".
Future<void> enterSelectionViaMenu(WidgetTester tester, {Finder? menu}) async {
  await tester.tap(menu ?? overflowMenuButton);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(selectItemsMenuKey));
  await tester.pumpAndSettle();
}
