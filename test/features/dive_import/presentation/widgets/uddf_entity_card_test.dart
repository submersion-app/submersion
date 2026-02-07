import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/presentation/widgets/uddf_entity_card.dart';

void main() {
  Widget buildTestWidget({
    String name = 'Test Item',
    String? subtitle,
    IconData icon = Icons.label_outline,
    bool isSelected = false,
    VoidCallback? onToggle,
    bool isDuplicate = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            UddfEntityCard(
              name: name,
              subtitle: subtitle,
              icon: icon,
              isSelected: isSelected,
              onToggle: onToggle ?? () {},
              isDuplicate: isDuplicate,
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('displays name', (tester) async {
    await tester.pumpWidget(buildTestWidget(name: 'My Trip'));
    expect(find.text('My Trip'), findsOneWidget);
  });

  testWidgets('displays subtitle when provided', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(name: 'Equipment', subtitle: 'BCD'),
    );
    expect(find.text('BCD'), findsOneWidget);
  });

  testWidgets('hides subtitle when null', (tester) async {
    await tester.pumpWidget(buildTestWidget(name: 'Tag'));
    expect(find.text('Tag'), findsOneWidget);
    // Only 1 text widget for the name, no subtitle
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    expect(textWidgets.length, 1);
  });

  testWidgets('displays entity icon', (tester) async {
    await tester.pumpWidget(buildTestWidget(icon: Icons.person_outline));
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('shows check icon when selected', (tester) async {
    await tester.pumpWidget(buildTestWidget(isSelected: true));
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('hides check icon when not selected', (tester) async {
    await tester.pumpWidget(buildTestWidget(isSelected: false));
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('shows duplicate badge when isDuplicate is true', (tester) async {
    await tester.pumpWidget(buildTestWidget(isDuplicate: true));
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('hides duplicate badge when isDuplicate is false', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(isDuplicate: false));
    expect(find.text('Duplicate'), findsNothing);
  });

  testWidgets('calls onToggle when tapped', (tester) async {
    var toggleCount = 0;
    await tester.pumpWidget(buildTestWidget(onToggle: () => toggleCount++));
    await tester.tap(find.byType(UddfEntityCard));
    expect(toggleCount, 1);
  });

  testWidgets('card has elevated style when selected', (tester) async {
    await tester.pumpWidget(buildTestWidget(isSelected: true));
    final card = tester.widget<Card>(find.byType(Card));
    expect(card.elevation, 2);
  });

  testWidgets('card has flat style when not selected', (tester) async {
    await tester.pumpWidget(buildTestWidget(isSelected: false));
    final card = tester.widget<Card>(find.byType(Card));
    expect(card.elevation, 0);
  });
}
