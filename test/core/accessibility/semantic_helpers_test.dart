import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';

void main() {
  group('SemanticWidgetExtensions', () {
    testWidgets('semanticButton wraps with button semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: const Text('Tap me').semanticButton(label: 'Action button'),
        ),
      );

      final semantics = tester.getSemantics(find.text('Tap me'));
      // Semantics tree merges parent label with child Text content
      expect(semantics.label, contains('Action button'));
      expect(semantics.flagsCollection.isButton, isTrue);

      handle.dispose();
    });

    testWidgets('semanticLabel wraps with label', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          // Use SizedBox instead of Icon to avoid name collision with
          // Icon.semanticLabel property
          home: const SizedBox(width: 24, height: 24).semanticLabel('Favorite'),
        ),
      );

      final semantics = tester.getSemantics(find.byType(SizedBox).last);
      expect(semantics.label, contains('Favorite'));

      handle.dispose();
    });

    testWidgets('excludeFromSemantics hides from tree', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: const Icon(Icons.water_drop).excludeFromSemantics()),
      );

      // MaterialApp adds its own ExcludeSemantics; verify ours wraps the Icon
      final finder = find.ancestor(
        of: find.byType(Icon),
        matching: find.byType(ExcludeSemantics),
      );
      expect(finder, findsOneWidget);
    });
  });

  group('chartSummaryLabel', () {
    test('combines chart type and description', () {
      expect(
        chartSummaryLabel(chartType: 'Bar', description: '42 dives in 2025'),
        equals('Bar chart. 42 dives in 2025'),
      );
    });
  });

  group('listItemLabel', () {
    test('returns title only when no extras', () {
      expect(listItemLabel(title: 'Blue Hole'), equals('Blue Hole'));
    });

    test('includes subtitle when provided', () {
      expect(
        listItemLabel(title: 'Blue Hole', subtitle: 'Belize'),
        equals('Blue Hole, Belize'),
      );
    });

    test('includes status when provided', () {
      expect(
        listItemLabel(
          title: 'BCD',
          subtitle: 'Aqualung',
          status: 'Service due',
        ),
        equals('BCD, Aqualung, Service due'),
      );
    });

    test('ignores empty subtitle and status', () {
      expect(
        listItemLabel(title: 'Item', subtitle: '', status: ''),
        equals('Item'),
      );
    });
  });

  group('statLabel', () {
    test('formats name and value', () {
      expect(
        statLabel(name: 'Total Dives', value: '142'),
        equals('Total Dives: 142'),
      );
    });

    test('includes unit when provided', () {
      expect(
        statLabel(name: 'Max Depth', value: '48.2', unit: 'm'),
        equals('Max Depth: 48.2 m'),
      );
    });
  });
}
