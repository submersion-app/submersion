import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('CollapsibleSection', () {
    testWidgets('renders title and icon', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: CollapsibleSection(
              title: 'Profile',
              icon: Icons.show_chart,
              isExpanded: false,
              onToggle: (_) {},
              child: const Text('Chart content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.byIcon(Icons.show_chart), findsOneWidget);
    });

    testWidgets('shows subtitle when collapsed and subtitle is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: CollapsibleSection(
              title: 'Equipment',
              icon: Icons.build,
              subtitle: '3 items',
              isExpanded: false,
              onToggle: (_) {},
              child: const Text('Gear list'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 items'), findsOneWidget);
    });

    testWidgets('hides subtitle when expanded', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: CollapsibleSection(
              title: 'Equipment',
              icon: Icons.build,
              subtitle: '3 items',
              isExpanded: true,
              onToggle: (_) {},
              child: const Text('Gear list'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 items'), findsNothing);
    });

    testWidgets('shows trailing widget when collapsed', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: CollapsibleSection(
              title: 'Notes',
              icon: Icons.note,
              trailing: const Chip(label: Text('Updated')),
              isExpanded: false,
              onToggle: (_) {},
              child: const Text('Note content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Updated'), findsOneWidget);
    });

    testWidgets('hides trailing widget when expanded', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: CollapsibleSection(
              title: 'Notes',
              icon: Icons.note,
              trailing: const Chip(label: Text('Updated')),
              isExpanded: true,
              onToggle: (_) {},
              child: const Text('Note content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Updated'), findsNothing);
    });

    testWidgets('calls onToggle with inverted value when tapped', (
      tester,
    ) async {
      bool? toggledValue;

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: CollapsibleSection(
              title: 'Profile',
              icon: Icons.show_chart,
              isExpanded: false,
              onToggle: (value) => toggledValue = value,
              child: const Text('Chart content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      expect(toggledValue, isTrue);
    });

    testWidgets('calls onToggle with false when already expanded', (
      tester,
    ) async {
      bool? toggledValue;

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: CollapsibleSection(
              title: 'Profile',
              icon: Icons.show_chart,
              isExpanded: true,
              onToggle: (value) => toggledValue = value,
              child: const Text('Chart content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      expect(toggledValue, isFalse);
    });

    testWidgets('shows expand_more icon', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: CollapsibleSection(
              title: 'Section',
              icon: Icons.info,
              isExpanded: false,
              onToggle: (_) {},
              child: const Text('Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });
  });

  group('CollapsibleCardSection', () {
    testWidgets('renders title and icon', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: CollapsibleCardSection(
              title: 'Data Sources',
              icon: Icons.devices,
              isExpanded: false,
              onToggle: (_) {},
              contentBuilder: (_) => const Text('Sources list'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Data Sources'), findsOneWidget);
      expect(find.byIcon(Icons.devices), findsOneWidget);
    });

    testWidgets('shows collapsedSubtitle when collapsed', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: CollapsibleCardSection(
              title: 'Data Sources',
              icon: Icons.devices,
              collapsedSubtitle: '2 sources',
              isExpanded: false,
              onToggle: (_) {},
              contentBuilder: (_) => const Text('Sources list'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 sources'), findsOneWidget);
    });

    testWidgets('hides collapsedSubtitle when expanded', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: CollapsibleCardSection(
              title: 'Data Sources',
              icon: Icons.devices,
              collapsedSubtitle: '2 sources',
              isExpanded: true,
              onToggle: (_) {},
              contentBuilder: (_) => const Text('Sources list'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 sources'), findsNothing);
    });

    testWidgets('shows collapsedTrailing only when collapsed', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: CollapsibleCardSection(
              title: 'Tanks',
              icon: MdiIcons.divingScubaTank,
              collapsedTrailing: const Icon(Icons.check_circle),
              isExpanded: false,
              onToggle: (_) {},
              contentBuilder: (_) => const Text('Tank info'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('hides collapsedTrailing when expanded', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: CollapsibleCardSection(
              title: 'Tanks',
              icon: MdiIcons.divingScubaTank,
              collapsedTrailing: const Icon(Icons.check_circle),
              isExpanded: true,
              onToggle: (_) {},
              contentBuilder: (_) => const Text('Tank info'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('always shows trailing widget regardless of expand state', (
      tester,
    ) async {
      for (final expanded in [false, true]) {
        await tester.pumpWidget(
          testApp(
            child: SingleChildScrollView(
              child: CollapsibleCardSection(
                title: 'Section',
                icon: Icons.info,
                trailing: const Icon(Icons.star),
                isExpanded: expanded,
                onToggle: (_) {},
                contentBuilder: (_) => const Text('Content'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.star),
          findsOneWidget,
          reason: 'trailing should be visible when expanded=$expanded',
        );
      }
    });

    testWidgets('calls onToggle when header tapped', (tester) async {
      bool? toggledValue;

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: CollapsibleCardSection(
              title: 'Data Sources',
              icon: Icons.devices,
              isExpanded: false,
              onToggle: (value) => toggledValue = value,
              contentBuilder: (_) => const Text('Sources list'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Data Sources'));
      expect(toggledValue, isTrue);
    });
  });
}
