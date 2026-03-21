import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_list_view_mode.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_view_mode_toggle.dart';

void main() {
  group('DiveListViewModeToggle', () {
    testWidgets('renders three icon buttons', (tester) async {
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

      expect(find.byIcon(Icons.view_agenda), findsOneWidget);
      expect(find.byIcon(Icons.view_list), findsOneWidget);
      expect(find.byIcon(Icons.list), findsOneWidget);
    });

    testWidgets('calls onModeChanged when tapped', (tester) async {
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

      await tester.tap(find.byIcon(Icons.view_list));
      expect(selected, DiveListViewMode.compact);

      await tester.tap(find.byIcon(Icons.list));
      expect(selected, DiveListViewMode.dense);
    });

    testWidgets('highlights current mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiveListViewModeToggle(
              currentMode: DiveListViewMode.compact,
              onModeChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(SegmentedButton<DiveListViewMode>), findsOneWidget);
    });
  });
}
