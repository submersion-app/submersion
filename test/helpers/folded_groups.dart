import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/collapsible_group_header.dart';

/// Opens every folded group on screen (issue #3364), for a test about the
/// rows rather than the folds. Equipment pickers start with their groups
/// closed, so a test that ticks an item opens the groups first.
Future<void> openFoldedGroups(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    final closed = find.byWidgetPredicate(
      (w) => w is CollapsibleGroupHeader && !w.isExpanded,
    );
    if (closed.evaluate().isEmpty) return;
    tester.widget<CollapsibleGroupHeader>(closed.first).onTap();
    await tester.pumpAndSettle();
  }
}
