import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/table_column_picker.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestTableConfigNotifier extends TableViewConfigNotifier {
  _TestTableConfigNotifier(TableViewConfig config) {
    state = config;
  }
}

final _testConfig = TableViewConfig(
  columns: [
    TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
    TableColumnConfig(field: DiveField.siteName, isPinned: true),
    TableColumnConfig(field: DiveField.dateTime),
    TableColumnConfig(field: DiveField.maxDepth),
    TableColumnConfig(field: DiveField.bottomTime),
  ],
);

Widget _buildPickerSheet({TableViewConfig? config}) {
  return testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      tableViewConfigProvider.overrideWith(
        (ref) => _TestTableConfigNotifier(config ?? _testConfig),
      ),
    ],
    child: Builder(
      builder: (context) {
        return ElevatedButton(
          onPressed: () => showTableColumnPicker(context),
          child: const Text('Open Picker'),
        );
      },
    ),
  );
}

void main() {
  group('TableColumnPicker', () {
    testWidgets('renders via showTableColumnPicker bottom sheet', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPickerSheet());
      await tester.pump();

      // Tap the button to open the bottom sheet
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // The bottom sheet header shows the "Columns" title
      expect(find.text('Columns'), findsOneWidget);
      // Done button is shown
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('shows VISIBLE COLUMNS section header', (tester) async {
      await tester.pumpWidget(_buildPickerSheet());
      await tester.pump();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
    });

    testWidgets('shows AVAILABLE FIELDS section header', (tester) async {
      await tester.pumpWidget(_buildPickerSheet());
      await tester.pump();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('AVAILABLE FIELDS'), findsOneWidget);
    });

    testWidgets('displays visible column names from config', (tester) async {
      await tester.pumpWidget(_buildPickerSheet());
      await tester.pump();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // displayName for visible columns (full names, not shortLabels)
      expect(find.text('Dive Number'), findsOneWidget);
      expect(find.text('Site Name'), findsOneWidget);
      expect(find.text('Date & Time'), findsOneWidget);
      expect(find.text('Max Depth'), findsOneWidget);
      expect(find.text('Bottom Time'), findsOneWidget);
    });

    testWidgets('pinned columns show filled push_pin icon', (tester) async {
      await tester.pumpWidget(_buildPickerSheet());
      await tester.pump();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // diveNumber and siteName are pinned
      expect(find.byIcon(Icons.push_pin), findsNWidgets(2));
    });

    testWidgets('unpinned columns show outlined push_pin icon', (tester) async {
      await tester.pumpWidget(_buildPickerSheet());
      await tester.pump();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // dateTime, maxDepth, bottomTime are unpinned
      expect(find.byIcon(Icons.push_pin_outlined), findsNWidgets(3));
    });

    testWidgets('unpinned columns show remove button', (tester) async {
      await tester.pumpWidget(_buildPickerSheet());
      await tester.pump();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // 3 unpinned columns should have remove button
      expect(find.byIcon(Icons.remove_circle_outline), findsNWidgets(3));
    });

    testWidgets('pinned columns do not show remove button', (tester) async {
      final pinnedOnly = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
        ],
      );
      await tester.pumpWidget(_buildPickerSheet(config: pinnedOnly));
      await tester.pump();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // No remove buttons when all columns are pinned
      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
    });

    testWidgets('available fields show add button', (tester) async {
      await tester.pumpWidget(_buildPickerSheet());
      await tester.pump();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Available fields that are not in the visible columns have add icons
      expect(find.byIcon(Icons.add_circle_outline), findsAtLeastNWidgets(1));
    });

    testWidgets('shows category headers for available fields', (tester) async {
      await tester.pumpWidget(_buildPickerSheet());
      await tester.pump();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // At least one category header should be visible (uppercased)
      // CORE category fields not all visible, so CORE shows up
      expect(find.text('CORE'), findsOneWidget);
    });

    testWidgets('Done button closes the bottom sheet', (tester) async {
      await tester.pumpWidget(_buildPickerSheet());
      await tester.pump();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Columns'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Bottom sheet should be dismissed
      expect(find.text('Columns'), findsNothing);
    });

    testWidgets('drag handles shown for visible columns', (tester) async {
      await tester.pumpWidget(_buildPickerSheet());
      await tester.pump();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // 5 visible columns should have drag handles
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(5));
    });

    testWidgets('tapping remove on unpinned column removes it', (tester) async {
      await tester.pumpWidget(_buildPickerSheet());
      await tester.pump();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Verify maxDepth is visible
      expect(find.text('Max Depth'), findsOneWidget);

      // Find the remove button for the 'Max Depth' row. Each unpinned
      // visible column has a remove_circle_outline button.
      // We'll tap the first remove icon after the maxDepth entry.
      // Since the list order is diveNumber(pinned), siteName(pinned),
      // dateTime, maxDepth, bottomTime, we want the second remove button
      // (dateTime=1st, maxDepth=2nd, bottomTime=3rd).
      final removeButtons = find.byIcon(Icons.remove_circle_outline);
      await tester.tap(removeButtons.at(1));
      await tester.pump();

      // maxDepth should no longer be in the visible columns but should
      // appear in available fields (as 'Max Depth').
      // Count of remove buttons should decrease by 1
      expect(find.byIcon(Icons.remove_circle_outline), findsNWidgets(2));
    });
  });
}
