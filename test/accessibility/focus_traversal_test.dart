import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/accessibility/focus_helpers.dart';

void main() {
  group('AccessiblePage', () {
    testWidgets(
      'wraps child in FocusTraversalGroup with OrderedTraversalPolicy',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AccessiblePage(
                child: Column(children: [Text('Child A'), Text('Child B')]),
              ),
            ),
          ),
        );

        // Framework adds its own FocusTraversalGroups, so filter by policy
        final groups = tester.widgetList<FocusTraversalGroup>(
          find.byType(FocusTraversalGroup),
        );
        final withOrderedPolicy = groups.where(
          (g) => g.policy is OrderedTraversalPolicy,
        );
        expect(withOrderedPolicy.isNotEmpty, isTrue);
      },
    );

    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AccessiblePage(child: Text('Page Content'))),
        ),
      );

      expect(find.text('Page Content'), findsOneWidget);
    });
  });

  group('FocusableCard', () {
    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusableCard(
              semanticLabel: 'Test card',
              onTap: () {},
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('has semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusableCard(
              semanticLabel: 'Dive card: Blue Hole',
              onTap: () {},
              child: const Text('Blue Hole'),
            ),
          ),
        ),
      );

      // Framework adds its own Semantics widgets, so filter by label
      final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final ours = semantics.where(
        (s) => s.properties.label == 'Dive card: Blue Hole',
      );
      expect(ours, hasLength(1));
    });

    testWidgets('is marked as button when onTap is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusableCard(
              semanticLabel: 'Tappable card',
              onTap: () {},
              child: const Text('Tap me'),
            ),
          ),
        ),
      );

      final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final ours = semantics.where(
        (s) => s.properties.label == 'Tappable card',
      );
      expect(ours, hasLength(1));
      expect(ours.first.properties.button, isTrue);
    });

    testWidgets('is not marked as button when onTap is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FocusableCard(
              semanticLabel: 'Non-tappable card',
              child: Text('Info only'),
            ),
          ),
        ),
      );

      final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final ours = semantics.where(
        (s) => s.properties.label == 'Non-tappable card',
      );
      expect(ours, hasLength(1));
      expect(ours.first.properties.button, isFalse);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusableCard(
              semanticLabel: 'Tappable',
              onTap: () => tapped = true,
              child: const Text('Tap'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap'));
      expect(tapped, isTrue);
    });

    testWidgets('shows focus ring when focused', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusableCard(
              semanticLabel: 'Focusable',
              onTap: () {},
              child: const Text('Focus me'),
            ),
          ),
        ),
      );

      // Access the FocusNode via Focus.of from a child element.
      // FocusableCard creates its FocusNode internally (not as a parameter),
      // so we reach it through the element tree.
      final childElement = tester.element(find.text('Focus me'));
      Focus.of(childElement).requestFocus();
      await tester.pumpAndSettle();

      // The AnimatedContainer should now have a border
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.border, isNotNull);
    });
  });
}
