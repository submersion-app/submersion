import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';

void main() {
  group('ListViewModeToggle', () {
    testWidgets('shows current mode icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListViewModeToggle(
              currentMode: ListViewMode.detailed,
              onModeChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.view_agenda), findsOneWidget);
      expect(find.byType(PopupMenuButton<ListViewMode>), findsOneWidget);
    });

    testWidgets('opens popup with all three options by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListViewModeToggle(
              currentMode: ListViewMode.detailed,
              onModeChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<ListViewMode>));
      await tester.pumpAndSettle();

      expect(find.text('Detailed'), findsOneWidget);
      expect(find.text('Compact'), findsOneWidget);
      expect(find.text('Dense'), findsOneWidget);
    });

    testWidgets('only shows availableModes when specified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListViewModeToggle(
              currentMode: ListViewMode.detailed,
              onModeChanged: (_) {},
              availableModes: [ListViewMode.detailed, ListViewMode.dense],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<ListViewMode>));
      await tester.pumpAndSettle();

      expect(find.text('Detailed'), findsOneWidget);
      expect(find.text('Compact'), findsNothing);
      expect(find.text('Dense'), findsOneWidget);
    });

    testWidgets('calls onModeChanged when option selected', (tester) async {
      ListViewMode? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListViewModeToggle(
              currentMode: ListViewMode.detailed,
              onModeChanged: (mode) => selected = mode,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<ListViewMode>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Compact'));
      await tester.pumpAndSettle();

      expect(selected, ListViewMode.compact);
    });
  });
}
