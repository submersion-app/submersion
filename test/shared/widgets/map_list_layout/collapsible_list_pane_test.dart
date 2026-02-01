import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/map_list_layout/collapsible_list_pane.dart';

void main() {
  Widget buildTestWidget({
    required bool isCollapsed,
    required VoidCallback onToggle,
    required Widget child,
    double width = 440,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            CollapsibleListPane(
              isCollapsed: isCollapsed,
              onToggle: onToggle,
              width: width,
              child: child,
            ),
            const Expanded(child: Placeholder()),
          ],
        ),
      ),
    );
  }

  testWidgets('shows child when not collapsed', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        isCollapsed: false,
        onToggle: () {},
        child: const Text('List Content'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('List Content'), findsOneWidget);
  });

  testWidgets('hides child when collapsed', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        isCollapsed: true,
        onToggle: () {},
        child: const Text('List Content'),
      ),
    );
    await tester.pumpAndSettle();
    // When collapsed, width should animate to 0
    final animatedContainer = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(animatedContainer.constraints?.maxWidth, 0);
  });

  testWidgets('shows collapse button when expanded', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        isCollapsed: false,
        onToggle: () {},
        child: const Text('List Content'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });

  testWidgets('calls onToggle when button pressed', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      buildTestWidget(
        isCollapsed: false,
        onToggle: () => toggled = true,
        child: const Text('List Content'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    expect(toggled, isTrue);
  });

  testWidgets('uses specified width when expanded', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        isCollapsed: false,
        onToggle: () {},
        width: 500,
        child: const Text('List Content'),
      ),
    );
    await tester.pumpAndSettle();
    final animatedContainer = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(animatedContainer.constraints?.maxWidth, 500);
  });
}
