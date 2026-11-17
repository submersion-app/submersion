import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unlocks a locked record page, as a diver does before a whole-record
/// operation (issue #4527): the menu's operations, the banners' actions and
/// the cards' operation controls run only on an unlocked page with nothing
/// to save. Does nothing on a page that is not locked. Found by its icon,
/// so it works in every locale.
Future<void> unlockForOperation(WidgetTester tester) async {
  final unlock = find.ancestor(
    of: find.byIcon(Icons.lock_outline),
    matching: find.byType(IconButton),
  );
  if (unlock.evaluate().isEmpty) return;
  await tester.tap(unlock.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
