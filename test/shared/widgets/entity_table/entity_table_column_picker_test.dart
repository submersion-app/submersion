import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_column_picker.dart';

import '../../../helpers/test_app.dart';

// ---------------------------------------------------------------------------
// Test field enum with two categories
// ---------------------------------------------------------------------------

class _TestField implements EntityField {
  static const entityName = _TestField._(
    name: 'entityName',
    displayName: 'Name',
    shortLabel: 'Name',
    categoryName: 'core',
    icon: Icons.label,
  );
  static const entityCount = _TestField._(
    name: 'entityCount',
    displayName: 'Count',
    shortLabel: 'Cnt',
    categoryName: 'core',
    icon: Icons.tag,
    isRightAligned: true,
  );
  static const entityStatus = _TestField._(
    name: 'entityStatus',
    displayName: 'Status',
    shortLabel: 'Stat',
    categoryName: 'details',
    icon: Icons.check_circle,
  );
  static const entityDescription = _TestField._(
    name: 'entityDescription',
    displayName: 'Description',
    shortLabel: 'Desc',
    categoryName: 'details',
  );

  static const List<_TestField> values = [
    entityName,
    entityCount,
    entityStatus,
    entityDescription,
  ];

  @override
  final String name;
  @override
  final String displayName;
  @override
  final String shortLabel;
  @override
  final String categoryName;
  @override
  final IconData? icon;
  @override
  final bool isRightAligned;

  const _TestField._({
    required this.name,
    required this.displayName,
    required this.shortLabel,
    required this.categoryName,
    this.icon,
    this.isRightAligned = false,
  });

  @override
  double get defaultWidth => 120;
  @override
  double get minWidth => 60;
  @override
  bool get sortable => true;

  @override
  bool operator ==(Object other) => other is _TestField && other.name == name;
  @override
  int get hashCode => name.hashCode;
}

// ---------------------------------------------------------------------------
// Concrete adapter
// ---------------------------------------------------------------------------

class _TestAdapter extends EntityFieldAdapter<dynamic, _TestField> {
  @override
  List<_TestField> get allFields => _TestField.values;

  @override
  Map<String, List<_TestField>> get fieldsByCategory => {
    'core': [_TestField.entityName, _TestField.entityCount],
    'details': [_TestField.entityStatus, _TestField.entityDescription],
  };

  @override
  dynamic extractValue(_TestField field, dynamic entity) => null;

  @override
  String formatValue(_TestField field, dynamic value, UnitFormatter units) =>
      value?.toString() ?? '--';

  @override
  _TestField fieldFromName(String name) =>
      _TestField.values.firstWhere((f) => f.name == name);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _adapter = _TestAdapter();

/// Config where name and count are visible; status and description are hidden.
final _config = EntityTableViewConfig<_TestField>(
  columns: [
    EntityTableColumnConfig(field: _TestField.entityName, isPinned: true),
    EntityTableColumnConfig(field: _TestField.entityCount),
  ],
);

/// Builds a scaffold with a button that opens the column picker bottom sheet.
Widget _buildPickerLauncher({
  EntityTableViewConfig<_TestField>? config,
  void Function(_TestField)? onToggleColumn,
  void Function(int, int)? onReorderColumn,
  void Function(_TestField)? onTogglePin,
}) {
  return testApp(
    child: Builder(
      builder: (context) {
        return ElevatedButton(
          onPressed: () => showEntityTableColumnPicker<_TestField>(
            context,
            config: config ?? _config,
            adapter: _adapter,
            onToggleColumn: onToggleColumn ?? (_) {},
            onReorderColumn: onReorderColumn ?? (_, _) {},
            onTogglePin: onTogglePin ?? (_) {},
          ),
          child: const Text('Open Picker'),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EntityTableColumnPicker', () {
    testWidgets('opens the picker dialog', (tester) async {
      await tester.pumpWidget(_buildPickerLauncher());
      await tester.pumpAndSettle();

      // Tap the launcher button
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // The bottom sheet should display with a "Columns" header
      expect(find.text('Columns'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('shows visible columns section with current column names', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPickerLauncher());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Section header
      expect(find.text('VISIBLE COLUMNS'), findsOneWidget);

      // Visible columns should show their displayName
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Count'), findsOneWidget);
    });

    testWidgets('shows available fields section with hidden fields', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPickerLauncher());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Section header
      expect(find.text('AVAILABLE FIELDS'), findsOneWidget);

      // Hidden fields should appear in the available section.
      // name and count are visible, so only status and description are hidden.
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
    });

    testWidgets('category headers are displayed for hidden fields', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPickerLauncher());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // "details" category has hidden fields (status, description) and should
      // show its uppercase header. "core" has all fields visible so its
      // category section is skipped.
      expect(find.text('DETAILS'), findsOneWidget);
    });

    testWidgets('toggling a hidden field calls onToggleColumn callback', (
      tester,
    ) async {
      _TestField? toggledField;

      await tester.pumpWidget(
        _buildPickerLauncher(onToggleColumn: (f) => toggledField = f),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Tap the "Add" button next to "Status"
      // The add button is an IconButton with add_circle_outline tooltip "Add"
      // near the Status text.
      final statusTile = find.widgetWithText(ListTile, 'Status');
      expect(statusTile, findsOneWidget);

      final addButton = find.descendant(
        of: statusTile,
        matching: find.byTooltip('Add'),
      );
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(toggledField, equals(_TestField.entityStatus));
    });

    testWidgets('removing a visible unpinned column calls onToggleColumn', (
      tester,
    ) async {
      _TestField? toggledField;

      await tester.pumpWidget(
        _buildPickerLauncher(onToggleColumn: (f) => toggledField = f),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Count is visible and not pinned, so it should have a "Remove" button.
      // The visible columns section uses ListTile with the field's displayName.
      // Find the ReorderableListView ListTile for "Count" and its remove button.
      final removeButtons = find.byTooltip('Remove');
      expect(removeButtons, findsWidgets);

      await tester.tap(removeButtons.first);
      await tester.pumpAndSettle();

      expect(toggledField, equals(_TestField.entityCount));
    });

    testWidgets(
      'pinned column shows filled pin icon, unpinned shows outlined',
      (tester) async {
        await tester.pumpWidget(_buildPickerLauncher());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Picker'));
        await tester.pumpAndSettle();

        // "Name" is pinned -- should show filled push_pin
        expect(find.byIcon(Icons.push_pin), findsOneWidget);
        // "Count" is not pinned -- should show outlined push_pin
        expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
      },
    );

    testWidgets('tapping pin icon calls onTogglePin callback', (tester) async {
      _TestField? pinnedField;

      await tester.pumpWidget(
        _buildPickerLauncher(onTogglePin: (f) => pinnedField = f),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Tap the "Unpin" tooltip on the pinned column (Name)
      final unpinButton = find.byTooltip('Unpin');
      expect(unpinButton, findsOneWidget);
      await tester.tap(unpinButton);
      await tester.pumpAndSettle();

      expect(pinnedField, equals(_TestField.entityName));
    });

    testWidgets('Done button closes the picker', (tester) async {
      await tester.pumpWidget(_buildPickerLauncher());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Columns'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // The bottom sheet should be dismissed
      expect(find.text('Columns'), findsNothing);
    });

    testWidgets('all fields visible hides available fields categories', (
      tester,
    ) async {
      // Config where ALL four fields are visible
      final allVisibleConfig = EntityTableViewConfig<_TestField>(
        columns: [
          EntityTableColumnConfig(field: _TestField.entityName, isPinned: true),
          EntityTableColumnConfig(field: _TestField.entityCount),
          EntityTableColumnConfig(field: _TestField.entityStatus),
          EntityTableColumnConfig(field: _TestField.entityDescription),
        ],
      );

      await tester.pumpWidget(_buildPickerLauncher(config: allVisibleConfig));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // All fields are visible, so no category sections should appear in the
      // available area. The AVAILABLE FIELDS label is always shown, but the
      // category sections (_AvailableCategorySection) return SizedBox.shrink.
      expect(find.text('CORE'), findsNothing);
      expect(find.text('DETAILS'), findsNothing);
    });
  });
}
