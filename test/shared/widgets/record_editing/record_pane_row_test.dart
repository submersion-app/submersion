import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/record_editing/record_pane_row.dart';

/// A list pane's header row while its record is unlocked: the unlocked row
/// laid over the locked one, which keeps its place (issue #4527).
void main() {
  const locked = SizedBox(height: 48, child: Text('Blue Hole'));
  const unlocked = Text('Editing Blue Hole');

  Future<void> pump(WidgetTester tester, Widget row) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(mainAxisSize: MainAxisSize.min, children: [row]),
      ),
    ),
  );

  testWidgets('locked alone shows the locked row', (tester) async {
    await pump(tester, const RecordPaneRow(locked: locked));

    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.text('Editing Blue Hole'), findsNothing);
  });

  testWidgets('unlocked lays its row over the locked one at the same height', (
    tester,
  ) async {
    await pump(tester, const RecordPaneRow(locked: locked, unlocked: unlocked));

    expect(find.text('Editing Blue Hole'), findsOneWidget);
    // The locked row keeps its place, unseen and not tappable.
    expect(find.text('Blue Hole').hitTestable(), findsNothing);
    expect(tester.getSize(find.byType(RecordPaneRow)).height, 48);
  });
}
