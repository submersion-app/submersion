import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
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
  String localizedDisplayName(AppLocalizations l10n) => displayName;
  @override
  String localizedShortLabel(AppLocalizations l10n) => shortLabel;

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

/// Config where name (pinned) and count are visible; status and description
/// are hidden. Safe to share across tests: the notifier copies it into state
/// and every mutation builds new lists rather than mutating in place.
final _config = EntityTableViewConfig<_TestField>(
  columns: [
    EntityTableColumnConfig(field: _TestField.entityName, isPinned: true),
    EntityTableColumnConfig(field: _TestField.entityCount),
  ],
);

/// Builds a fresh provider backed by a real [EntityTableConfigNotifier], so
/// the picker exercises the same subscription path it uses in the app.
EntityTableConfigProvider<_TestField> _makeConfigProvider(
  EntityTableViewConfig<_TestField> initial,
) {
  return StateNotifierProvider<
    EntityTableConfigNotifier<_TestField>,
    EntityTableViewConfig<_TestField>
  >(
    (ref) => EntityTableConfigNotifier<_TestField>(
      defaultConfig: initial,
      fieldFromName: _adapter.fieldFromName,
    ),
  );
}

/// Builds a scaffold with a button that opens the column picker bottom sheet.
///
/// Pass [provider] when the test needs to drive the notifier directly;
/// otherwise a fresh provider is created from [config].
Widget _buildPickerLauncher({
  EntityTableViewConfig<_TestField>? config,
  EntityTableConfigProvider<_TestField>? provider,
  Locale? locale,
}) {
  final configProvider = provider ?? _makeConfigProvider(config ?? _config);
  return testApp(
    locale: locale,
    child: Builder(
      builder: (context) {
        return ElevatedButton(
          onPressed: () => showEntityTableColumnPicker<_TestField>(
            context,
            configProvider: configProvider,
            adapter: _adapter,
          ),
          child: const Text('Open Picker'),
        );
      },
    ),
  );
}

/// Reads the [ProviderContainer] backing the open sheet, so a test can mutate
/// the notifier the way non-picker code would and assert the sheet reacts.
ProviderContainer _containerOf(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(EntityTableColumnPicker<_TestField>)),
  );
}

/// Drains the notifier's 500 ms save debounce. `pumpAndSettle` does not do
/// this: a bare Timer schedules no frames, and `testWidgets` fails a test that
/// ends with a timer still pending.
Future<void> _drainSaveDebounce(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
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

    testWidgets('pinning a column updates the sheet without reopening it', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPickerLauncher());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Name is pinned, Count is not.
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);

      // Pin Count -- the only column offering a "Pin" tooltip.
      await tester.tap(find.byTooltip('Pin'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.push_pin), findsNWidgets(2));
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
      // Pinned columns cannot be removed, so no Remove button survives.
      expect(find.byTooltip('Remove'), findsNothing);

      await _drainSaveDebounce(tester);
    });

    testWidgets('unpinning a column reveals its Remove button immediately', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPickerLauncher());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Only Count (unpinned) offers Remove.
      expect(find.byTooltip('Remove'), findsOneWidget);

      await tester.tap(find.byTooltip('Unpin'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.push_pin), findsNothing);
      expect(find.byIcon(Icons.push_pin_outlined), findsNWidgets(2));
      expect(find.byTooltip('Remove'), findsNWidgets(2));

      await _drainSaveDebounce(tester);
    });

    testWidgets(
      'removing a column moves it into AVAILABLE FIELDS immediately',
      (tester) async {
        await tester.pumpWidget(_buildPickerLauncher());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Picker'));
        await tester.pumpAndSettle();

        // Status and description are hidden; the core category is fully
        // visible.
        expect(find.byTooltip('Add'), findsNWidgets(2));
        expect(find.text('CORE'), findsNothing);

        await tester.tap(find.byTooltip('Remove'));
        await tester.pumpAndSettle();

        // Count now sits in the available section with an Add button.
        final countTile = find.widgetWithText(ListTile, 'Count');
        expect(countTile, findsOneWidget);
        expect(
          find.descendant(of: countTile, matching: find.byTooltip('Add')),
          findsOneWidget,
        );
        expect(find.byTooltip('Add'), findsNWidgets(3));
        // The core category now has a hidden field, so its header appears.
        expect(find.text('CORE'), findsOneWidget);

        await _drainSaveDebounce(tester);
      },
    );

    testWidgets('adding a field moves it into VISIBLE COLUMNS immediately', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPickerLauncher());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Two visible columns means two drag handles.
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));

      final statusTile = find.widgetWithText(ListTile, 'Status');
      await tester.tap(
        find.descendant(of: statusTile, matching: find.byTooltip('Add')),
      );
      await tester.pumpAndSettle();

      // Status is now a visible column: it has a drag handle and a Pin button.
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
      final promotedStatus = find.widgetWithText(ListTile, 'Status');
      expect(
        find.descendant(of: promotedStatus, matching: find.byTooltip('Pin')),
        findsOneWidget,
      );
      // Only Description is left to add, and its category header still shows.
      expect(find.byTooltip('Add'), findsOneWidget);
      expect(find.text('DETAILS'), findsOneWidget);

      // Adding the last hidden field empties the category, which must drop its
      // header on the same rebuild.
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_handle), findsNWidgets(4));
      expect(find.byTooltip('Add'), findsNothing);
      expect(find.text('DETAILS'), findsNothing);

      await _drainSaveDebounce(tester);
    });

    testWidgets('sheet re-renders when the config changes from outside', (
      tester,
    ) async {
      final provider = _makeConfigProvider(_config);
      await tester.pumpWidget(_buildPickerLauncher(provider: provider));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Initial order: Name then Count.
      final initialOrder = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title! as Text).data)
          .toList();
      expect(initialOrder.take(2), equals(['Name', 'Count']));

      // Move Count above Name through the notifier, exactly as a completed
      // drag would. The open sheet must pick this up on its own.
      _containerOf(tester).read(provider.notifier).reorderColumn(1, 0);
      await tester.pumpAndSettle();

      final reordered = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title! as Text).data)
          .toList();
      expect(reordered.take(2), equals(['Count', 'Name']));

      await _drainSaveDebounce(tester);
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

    testWidgets('sheet labels follow the app locale', (tester) async {
      await tester.pumpWidget(_buildPickerLauncher(locale: const Locale('de')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Spalten'), findsOneWidget);
      expect(find.text('Fertig'), findsOneWidget);
      expect(find.text('SICHTBARE SPALTEN'), findsOneWidget);
      expect(find.text('VERFÜGBARE FELDER'), findsOneWidget);
    });
  });
}
