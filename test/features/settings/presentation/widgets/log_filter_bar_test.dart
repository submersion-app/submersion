import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/widgets/log_filter_bar.dart';

void main() {
  Widget buildTestWidget() {
    return const ProviderScope(
      child: MaterialApp(home: Scaffold(body: LogFilterBar())),
    );
  }

  group('LogFilterBar', () {
    testWidgets('renders all category chips', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('App'), findsOneWidget);
      expect(find.text('Bluetooth'), findsOneWidget);
      expect(find.text('Serial'), findsOneWidget);
      expect(find.text('libdc'), findsOneWidget);
      expect(find.text('Database'), findsOneWidget);
    });

    testWidgets('all category chips are selected by default', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      for (final chip in chips) {
        expect(chip.selected, isTrue);
      }
    });

    testWidgets('tapping a chip deselects it', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // All 5 chips should be selected initially
      final chipsBefore = tester.widgetList<FilterChip>(
        find.byType(FilterChip),
      );
      expect(chipsBefore.every((c) => c.selected), isTrue);

      // Tap the "App" chip to deselect it
      await tester.tap(find.widgetWithText(FilterChip, 'App'));
      await tester.pump();

      // Now the App chip should be deselected
      final appChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'App'),
      );
      expect(appChip.selected, isFalse);

      // Other chips should remain selected
      final bleChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Bluetooth'),
      );
      expect(bleChip.selected, isTrue);
    });

    testWidgets('cannot deselect last remaining chip', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Deselect 4 of the 5 chips
      await tester.tap(find.widgetWithText(FilterChip, 'App'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'Bluetooth'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'Serial'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'libdc'));
      await tester.pump();

      // Only "Database" chip should remain selected
      final dbChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Database'),
      );
      expect(dbChip.selected, isTrue);

      // Tap the last chip — should remain selected (can't deselect all)
      await tester.tap(find.widgetWithText(FilterChip, 'Database'));
      await tester.pump();

      final dbChipAfter = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Database'),
      );
      expect(dbChipAfter.selected, isTrue);
    });

    testWidgets('tapping a deselected chip re-selects it', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Deselect App
      await tester.tap(find.widgetWithText(FilterChip, 'App'));
      await tester.pump();

      final appChipAfterDeselect = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'App'),
      );
      expect(appChipAfterDeselect.selected, isFalse);

      // Re-select App
      await tester.tap(find.widgetWithText(FilterChip, 'App'));
      await tester.pump();

      final appChipAfterReselect = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'App'),
      );
      expect(appChipAfterReselect.selected, isTrue);
    });

    testWidgets('renders min severity label', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('Min severity: '), findsOneWidget);
    });

    testWidgets('renders severity dropdown', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(DropdownButton<LogLevel>), findsOneWidget);
    });

    testWidgets('severity dropdown shows debug as default', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final dropdown = tester.widget<DropdownButton<LogLevel>>(
        find.byType(DropdownButton<LogLevel>),
      );
      expect(dropdown.value, LogLevel.debug);
    });

    testWidgets('severity dropdown changes when a new level is selected', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Open the dropdown
      await tester.tap(find.byType(DropdownButton<LogLevel>));
      await tester.pumpAndSettle();

      // Select 'WARNING' — find by text tag 'WARN'
      final warnItems = find.text('WARN');
      // The dropdown shows the current selected item in the button plus options
      // We want to tap the item in the dropdown menu (not the button label)
      await tester.tap(warnItems.last);
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButton<LogLevel>>(
        find.byType(DropdownButton<LogLevel>),
      );
      expect(dropdown.value, LogLevel.warning);
    });

    testWidgets('severity dropdown shows all LogLevel options when opened', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byType(DropdownButton<LogLevel>));
      await tester.pumpAndSettle();

      // All level tags should be visible in the open dropdown
      expect(find.text('DEBUG'), findsWidgets);
      expect(find.text('INFO'), findsOneWidget);
      expect(find.text('WARN'), findsOneWidget);
      expect(find.text('ERROR'), findsOneWidget);
    });
  });
}
