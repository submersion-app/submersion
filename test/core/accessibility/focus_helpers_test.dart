import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/accessibility/focus_helpers.dart';

void main() {
  group('AccessiblePage', () {
    testWidgets('wraps child in FocusTraversalGroup', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AccessiblePage(child: Text('Page content'))),
      );

      // MaterialApp also uses FocusTraversalGroup, so scope to AccessiblePage
      final finder = find.descendant(
        of: find.byType(AccessiblePage),
        matching: find.byType(FocusTraversalGroup),
      );
      expect(finder, findsOneWidget);
      expect(find.text('Page content'), findsOneWidget);
    });

    testWidgets('uses OrderedTraversalPolicy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AccessiblePage(child: Text('Content'))),
      );

      // Scope to the FocusTraversalGroup inside AccessiblePage
      final finder = find.descendant(
        of: find.byType(AccessiblePage),
        matching: find.byType(FocusTraversalGroup),
      );
      final group = tester.widget<FocusTraversalGroup>(finder);
      expect(group.policy, isA<OrderedTraversalPolicy>());
    });
  });

  group('FocusableCard', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FocusableCard(
            semanticLabel: 'Test card',
            child: Text('Card content'),
          ),
        ),
      );

      expect(find.text('Card content'), findsOneWidget);
    });

    testWidgets('provides semantic label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FocusableCard(
            semanticLabel: 'Dive at Blue Hole',
            child: Text('Card'),
          ),
        ),
      );

      // Use byWidgetPredicate to find our specific Semantics widget
      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Dive at Blue Hole',
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('shows focus indicator when focused', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusableCard(
              semanticLabel: 'Focusable item',
              onTap: () {},
              child: const Text('Focus me'),
            ),
          ),
        ),
      );

      // Tab into the FocusableCard to trigger focus
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // When focused, the AnimatedContainer should have a border
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.border, isNotNull);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: FocusableCard(
            semanticLabel: 'Tappable card',
            onTap: () => tapped = true,
            child: const Text('Tap me'),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      expect(tapped, isTrue);
    });

    testWidgets('marks as button when onTap is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FocusableCard(
            semanticLabel: 'Button card',
            onTap: () {},
            child: const Text('Content'),
          ),
        ),
      );

      // Use byWidgetPredicate to find our specific Semantics widget
      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Button card',
      );
      final semantics = tester.widget<Semantics>(semanticsFinder);
      expect(semantics.properties.button, isTrue);
    });
  });
}
