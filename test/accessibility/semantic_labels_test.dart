import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/accessibility/focus_helpers.dart';

void main() {
  group('SemanticWidgetExtensions', () {
    testWidgets('semanticButton wraps with button semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Text('Tap me').semanticButton(label: 'Action button'),
          ),
        ),
      );

      // Find the Semantics widget we added (has a label property set)
      final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final ours = semantics.where(
        (s) => s.properties.label == 'Action button',
      );
      expect(ours, hasLength(1));
      expect(ours.first.properties.button, isTrue);
    });

    testWidgets('semanticLabel wraps with label semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SizedBox(
              width: 24,
              height: 24,
            ).semanticLabel('5 stars'),
          ),
        ),
      );

      final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final ours = semantics.where((s) => s.properties.label == '5 stars');
      expect(ours, hasLength(1));
    });

    testWidgets('excludeFromSemantics wraps with ExcludeSemantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: const Icon(Icons.circle).excludeFromSemantics()),
        ),
      );

      expect(find.byType(ExcludeSemantics), findsAtLeast(1));
    });
  });

  group('chartSummaryLabel', () {
    test('combines chart type and description', () {
      final label = chartSummaryLabel(
        chartType: 'Bar',
        description: '42 dives in 2025, 38 in 2024',
      );

      expect(label, 'Bar chart. 42 dives in 2025, 38 in 2024');
    });

    test('works with different chart types', () {
      final label = chartSummaryLabel(
        chartType: 'Line',
        description: 'Depth progression from 10m to 45m over 2 years',
      );

      expect(label, startsWith('Line chart.'));
    });
  });

  group('listItemLabel', () {
    test('returns title only when no subtitle or status', () {
      final label = listItemLabel(title: 'Blue Hole');
      expect(label, 'Blue Hole');
    });

    test('combines title and subtitle', () {
      final label = listItemLabel(title: 'Blue Hole', subtitle: 'Belize');
      expect(label, 'Blue Hole, Belize');
    });

    test('combines title, subtitle, and status', () {
      final label = listItemLabel(
        title: 'Blue Hole',
        subtitle: 'Belize',
        status: '32m max depth',
      );
      expect(label, 'Blue Hole, Belize, 32m max depth');
    });

    test('skips empty subtitle', () {
      final label = listItemLabel(title: 'Blue Hole', subtitle: '');
      expect(label, 'Blue Hole');
    });

    test('skips null status', () {
      final label = listItemLabel(title: 'Blue Hole', subtitle: 'Belize');
      expect(label, 'Blue Hole, Belize');
    });
  });

  group('statLabel', () {
    test('formats name and value', () {
      final label = statLabel(name: 'Total dives', value: '142');
      expect(label, 'Total dives: 142');
    });

    test('includes unit when provided', () {
      final label = statLabel(name: 'Max depth', value: '48', unit: 'm');
      expect(label, 'Max depth: 48 m');
    });

    test('omits unit when null', () {
      final label = statLabel(name: 'Dive count', value: '50');
      expect(label, 'Dive count: 50');
    });
  });

  group('FocusableCard semantic integration', () {
    testWidgets('provides descriptive label for screen readers', (
      tester,
    ) async {
      final expectedLabel = listItemLabel(
        title: 'Dive 42',
        subtitle: 'Blue Hole',
        status: '32m, 48 min',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusableCard(
              semanticLabel: expectedLabel,
              onTap: () {},
              child: const Text('Dive 42'),
            ),
          ),
        ),
      );

      // Find our Semantics widget by matching the label
      final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final ours = semantics.where((s) => s.properties.label == expectedLabel);
      expect(ours, hasLength(1));
      expect(ours.first.properties.button, isTrue);
      expect(expectedLabel, 'Dive 42, Blue Hole, 32m, 48 min');
    });
  });
}
