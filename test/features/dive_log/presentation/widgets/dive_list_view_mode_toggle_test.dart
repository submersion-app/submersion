import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_list_view_mode.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart';

void main() {
  group('DiveListViewModeToggle', () {
    testWidgets('shows current mode icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiveListViewModeToggle(
              currentMode: DiveListViewMode.detailed,
              onModeChanged: (_) {},
            ),
          ),
        ),
      );

      // Shows the icon for the current mode
      expect(find.byIcon(Icons.view_agenda), findsOneWidget);
      expect(find.byType(PopupMenuButton<DiveListViewMode>), findsOneWidget);
    });

    testWidgets('opens popup with all three options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiveListViewModeToggle(
              currentMode: DiveListViewMode.detailed,
              onModeChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap the button to open the popup menu
      await tester.tap(find.byType(PopupMenuButton<DiveListViewMode>));
      await tester.pumpAndSettle();

      expect(find.text('Detailed'), findsOneWidget);
      expect(find.text('Compact'), findsOneWidget);
      expect(find.text('Dense'), findsOneWidget);
    });

    testWidgets('calls onModeChanged when option selected', (tester) async {
      DiveListViewMode? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiveListViewModeToggle(
              currentMode: DiveListViewMode.detailed,
              onModeChanged: (mode) => selected = mode,
            ),
          ),
        ),
      );

      // Open popup
      await tester.tap(find.byType(PopupMenuButton<DiveListViewMode>));
      await tester.pumpAndSettle();

      // Select compact
      await tester.tap(find.text('Compact'));
      await tester.pumpAndSettle();

      expect(selected, DiveListViewMode.compact);
    });
  });
}
