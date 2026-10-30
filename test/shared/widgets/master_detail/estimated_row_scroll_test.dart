import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/master_detail/estimated_row_scroll.dart';

void main() {
  late ScrollController controller;

  Future<void> pumpList(WidgetTester tester) async {
    controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            controller: controller,
            itemCount: 100,
            itemBuilder: (_, i) => SizedBox(height: 50, child: Text('Row $i')),
          ),
        ),
      ),
    );
  }

  testWidgets('jumps a far row into view', (tester) async {
    await pumpList(tester);

    scrollToEstimatedRow(controller, index: 70, rowCount: 100, jump: true);
    // Measured after one frame, drawn in the next.
    await tester.pump();
    await tester.pump();

    expect(find.text('Row 70'), findsOneWidget);
    expect(find.text('Row 0'), findsNothing);
  });

  testWidgets('animates there when not jumping', (tester) async {
    await pumpList(tester);

    scrollToEstimatedRow(controller, index: 70, rowCount: 100);
    await tester.pump();
    expect(find.text('Row 70'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Row 70'), findsOneWidget);
  });
}
