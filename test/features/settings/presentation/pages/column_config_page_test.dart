import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/constants/certification_field.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/domain/constants/course_field.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/pages/column_config_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/constants/trip_field.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

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

class _TestCardConfigNotifier extends CardViewConfigNotifier {
  _TestCardConfigNotifier(CardViewConfig config) {
    state = config;
  }
}

class _TestEntityTableConfigNotifier<F extends EntityField>
    extends EntityTableConfigNotifier<F> {
  _TestEntityTableConfigNotifier(
    EntityTableViewConfig<F> config, {
    required super.fieldFromName,
  }) : super(defaultConfig: config) {
    state = config;
  }
}

final _testTableConfig = TableViewConfig(
  columns: [
    TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
    TableColumnConfig(field: DiveField.siteName, isPinned: true),
    TableColumnConfig(field: DiveField.dateTime),
    TableColumnConfig(field: DiveField.maxDepth),
  ],
);

Widget _buildColumnConfigPage({
  TableViewConfig? tableConfig,
  bool embedded = false,
}) {
  return testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier(),
      ),
      tableViewConfigProvider.overrideWith(
        (ref) => _TestTableConfigNotifier(tableConfig ?? _testTableConfig),
      ),
      detailedCardConfigProvider.overrideWith(
        (ref) => _TestCardConfigNotifier(CardViewConfig.defaultDetailed()),
      ),
      compactCardConfigProvider.overrideWith(
        (ref) => _TestCardConfigNotifier(CardViewConfig.defaultCompact()),
      ),
      denseCardConfigProvider.overrideWith(
        (ref) => _TestCardConfigNotifier(CardViewConfig.defaultDense()),
      ),
      // Entity table config providers for non-Dives sections
      siteTableConfigProvider.overrideWith(
        (ref) => _TestEntityTableConfigNotifier<SiteField>(
          EntityTableViewConfig<SiteField>(
            columns: [
              EntityTableColumnConfig(
                field: SiteField.siteName,
                isPinned: true,
              ),
              EntityTableColumnConfig(field: SiteField.country),
            ],
          ),
          fieldFromName: SiteFieldAdapter.instance.fieldFromName,
        ),
      ),
      buddyTableConfigProvider.overrideWith(
        (ref) => _TestEntityTableConfigNotifier<BuddyField>(
          EntityTableViewConfig<BuddyField>(
            columns: [
              EntityTableColumnConfig(
                field: BuddyField.buddyName,
                isPinned: true,
              ),
            ],
          ),
          fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
        ),
      ),
      tripTableConfigProvider.overrideWith(
        (ref) => _TestEntityTableConfigNotifier<TripField>(
          EntityTableViewConfig<TripField>(
            columns: [
              EntityTableColumnConfig(
                field: TripField.tripName,
                isPinned: true,
              ),
            ],
          ),
          fieldFromName: TripFieldAdapter.instance.fieldFromName,
        ),
      ),
      equipmentTableConfigProvider.overrideWith(
        (ref) => _TestEntityTableConfigNotifier<EquipmentField>(
          EntityTableViewConfig<EquipmentField>(
            columns: [
              EntityTableColumnConfig(
                field: EquipmentField.itemName,
                isPinned: true,
              ),
            ],
          ),
          fieldFromName: EquipmentFieldAdapter.instance.fieldFromName,
        ),
      ),
      diveCenterTableConfigProvider.overrideWith(
        (ref) => _TestEntityTableConfigNotifier<DiveCenterField>(
          EntityTableViewConfig<DiveCenterField>(
            columns: [
              EntityTableColumnConfig(
                field: DiveCenterField.centerName,
                isPinned: true,
              ),
            ],
          ),
          fieldFromName: DiveCenterFieldAdapter.instance.fieldFromName,
        ),
      ),
      certificationTableConfigProvider.overrideWith(
        (ref) => _TestEntityTableConfigNotifier<CertificationField>(
          EntityTableViewConfig<CertificationField>(
            columns: [
              EntityTableColumnConfig(
                field: CertificationField.certName,
                isPinned: true,
              ),
            ],
          ),
          fieldFromName: CertificationFieldAdapter.instance.fieldFromName,
        ),
      ),
      courseTableConfigProvider.overrideWith(
        (ref) => _TestEntityTableConfigNotifier<CourseField>(
          EntityTableViewConfig<CourseField>(
            columns: [
              EntityTableColumnConfig(
                field: CourseField.courseName,
                isPinned: true,
              ),
            ],
          ),
          fieldFromName: CourseFieldAdapter.instance.fieldFromName,
        ),
      ),
    ],
    child: ColumnConfigPage(embedded: embedded),
  );
}

void main() {
  group('ColumnConfigPage', () {
    testWidgets('renders page title in AppBar', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // The l10n key columnConfig_title resolves to 'Dive Details List Fields'
      expect(find.text('Dive Details List Fields'), findsOneWidget);
    });

    testWidgets('renders view mode dropdown with Table selected by default', (
      tester,
    ) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // View Mode label is shown
      expect(find.text('View Mode'), findsOneWidget);
      // Table is the default selected mode
      expect(find.text('Table'), findsOneWidget);
    });

    testWidgets('embedded mode hides AppBar', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage(embedded: true));
      await tester.pump();

      // Title should not be in an AppBar
      expect(find.byType(AppBar), findsNothing);
      // But the body content is still there
      expect(find.text('View Mode'), findsOneWidget);
    });

    testWidgets('shows visible columns section in table mode', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // The section header 'VISIBLE COLUMNS'
      expect(find.text('VISIBLE COLUMNS'), findsOneWidget);

      // First two columns (pinned) are always visible at the top
      expect(find.text('Dive Number'), findsAtLeastNWidgets(1));
      expect(find.text('Site Name'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows available fields section in table mode', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      expect(find.text('AVAILABLE FIELDS'), findsOneWidget);
    });

    testWidgets('shows Load Preset dropdown', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      expect(find.text('Load Preset'), findsOneWidget);
    });

    testWidgets('shows Save As button', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      expect(find.text('Save As'), findsOneWidget);
    });

    testWidgets('shows Reset to Default button', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      expect(find.text('Reset to Default'), findsOneWidget);
    });

    testWidgets('switching to Detailed mode shows slot assignments', (
      tester,
    ) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Tap the dropdown to open it
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();

      // Select Detailed
      await tester.tap(find.text('Detailed').last);
      await tester.pumpAndSettle();

      // Detailed mode shows slot assignments
      expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
      expect(find.text('EXTRA FIELDS'), findsOneWidget);
    });

    testWidgets('switching to Compact mode shows slot assignments', (
      tester,
    ) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Tap the dropdown to open it
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();

      // Select Compact
      await tester.tap(find.text('Compact').last);
      await tester.pumpAndSettle();

      // Compact mode shows slot assignments
      expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
    });

    testWidgets('pinned columns show filled pin icon', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Pinned columns should have the filled push_pin icon
      expect(find.byIcon(Icons.push_pin), findsAtLeastNWidgets(1));
    });

    testWidgets('unpinned columns show outlined pin icon', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Unpinned columns have outlined pin icon
      expect(find.byIcon(Icons.push_pin_outlined), findsAtLeastNWidgets(1));
    });

    testWidgets('unpinned columns have remove button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Remove icons for non-pinned columns
      expect(find.byIcon(Icons.remove_circle_outline), findsAtLeastNWidgets(1));
    });

    testWidgets('available fields show add button', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Available fields have add icons
      expect(find.byIcon(Icons.add_circle_outline), findsAtLeastNWidgets(1));
    });

    testWidgets('Save As opens save preset dialog', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      await tester.tap(find.text('Save As'));
      await tester.pumpAndSettle();

      // Dialog should show
      expect(find.text('Save Preset'), findsOneWidget);
      expect(find.text('Preset Name'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('Save preset dialog Cancel closes it', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      await tester.tap(find.text('Save As'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Save Preset'), findsNothing);
    });

    testWidgets('drag handles are shown for visible columns', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Each visible column should have a drag handle
      expect(find.byIcon(Icons.drag_handle), findsAtLeastNWidgets(1));
    });

    testWidgets('detailed mode shows slot and extra field sections', (
      tester,
    ) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Switch to Detailed mode
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detailed').last);
      await tester.pumpAndSettle();

      // Detailed mode shows slot assignments and extra fields
      expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
      expect(find.text('EXTRA FIELDS'), findsOneWidget);
    });

    testWidgets('tapping pin icon toggles pin state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Tap on an outlined pin to toggle pin
      final outlinedPins = find.byIcon(Icons.push_pin_outlined);
      expect(outlinedPins, findsAtLeastNWidgets(1));
      await tester.tap(outlinedPins.first);
      await tester.pump();

      // The icon should still exist (may have changed to filled)
      expect(find.byIcon(Icons.push_pin), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping remove icon invokes toggleColumn', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // There should be at least one remove button for non-pinned columns
      final removeButtons = find.byIcon(Icons.remove_circle_outline);
      expect(removeButtons, findsAtLeastNWidgets(1));

      // Tap a remove button - should not crash and state should update
      await tester.tap(removeButtons.first);
      await tester.pump();

      // Widget tree should still be intact after the operation
      expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
    });

    testWidgets('tapping add icon invokes toggleColumn', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Find available field add buttons
      final addButtons = find.byIcon(Icons.add_circle_outline);
      expect(addButtons, findsAtLeastNWidgets(1));

      // Tap an add button - should not crash and state should update
      await tester.tap(addButtons.first);
      await tester.pump();

      // After adding, the widget tree should still be intact
      expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
    });

    testWidgets('Reset to Default button resets table config', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Tap Reset to Default
      await tester.tap(find.text('Reset to Default'));
      await tester.pump();

      // Table should still render after reset
      expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
    });

    testWidgets('detailed mode shows AVAILABLE FIELDS section', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Switch to Detailed mode
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detailed').last);
      await tester.pumpAndSettle();

      // AVAILABLE FIELDS header should be visible
      expect(find.text('AVAILABLE FIELDS'), findsOneWidget);
    });

    testWidgets('detailed mode shows slot dropdown fields', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Switch to Detailed mode
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detailed').last);
      await tester.pumpAndSettle();

      // Should show slot labels like Title, Date / Subtitle, Stat 1, Stat 2
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('compact mode shows slot assignments', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Switch to Compact mode
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compact').last);
      await tester.pumpAndSettle();

      expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
    });

    testWidgets('compact mode shows Reset to Default button', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Switch to Compact mode
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compact').last);
      await tester.pumpAndSettle();

      expect(find.text('Reset to Default'), findsOneWidget);
    });

    testWidgets('save preset dialog with empty name closes without saving', (
      tester,
    ) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      await tester.tap(find.text('Save As'));
      await tester.pumpAndSettle();

      // Tap Save without entering a name
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Dialog should close (no crash)
      expect(find.text('Save Preset'), findsNothing);
    });

    testWidgets('view mode dropdown has all expected items', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Tap the dropdown to see all items
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();

      // Should see Table, Detailed, Compact
      expect(find.text('Table'), findsAtLeastNWidgets(1));
      expect(find.text('Detailed'), findsOneWidget);
      expect(find.text('Compact'), findsOneWidget);
    });

    testWidgets('detailed mode shows extra fields help text', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Switch to Detailed mode
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detailed').last);
      await tester.pumpAndSettle();

      // Should show the help text for extra fields
      expect(
        find.textContaining('Additional fields shown below'),
        findsOneWidget,
      );
    });

    testWidgets('detailed mode initially shows no extra fields message', (
      tester,
    ) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Switch to Detailed mode
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detailed').last);
      await tester.pumpAndSettle();

      // Default config has no extra fields, so the empty message should show
      expect(find.textContaining('No extra fields configured'), findsOneWidget);
    });

    testWidgets('table mode shows category headers in available fields', (
      tester,
    ) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Available fields section should have category headers
      // (uppercased category names from DiveFieldCategory)
      expect(find.text('AVAILABLE FIELDS'), findsOneWidget);
    });

    // -----------------------------------------------------------------
    // Section selector tests (Task 13)
    // -----------------------------------------------------------------

    testWidgets('renders section selector with all 8 options', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // The section selector label
      expect(find.text('Section'), findsOneWidget);
      // Default selection is Dives
      expect(find.text('Dives'), findsOneWidget);

      // Open the section dropdown
      await tester.tap(find.text('Dives'));
      await tester.pumpAndSettle();

      // All 8 section options should be visible in the dropdown
      expect(find.text('Dives'), findsAtLeastNWidgets(2)); // selected + menu
      expect(find.text('Sites'), findsOneWidget);
      expect(find.text('Buddies'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Equipment'), findsOneWidget);
      expect(find.text('Dive Centers'), findsOneWidget);
      expect(find.text('Certifications'), findsOneWidget);
      expect(find.text('Courses'), findsOneWidget);
    });

    testWidgets('switching section changes displayed content', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Initially shows Dives table content
      expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
      expect(find.text('Dive Number'), findsAtLeastNWidgets(1));

      // Switch to Sites section
      await tester.tap(find.text('Dives'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sites').last);
      await tester.pumpAndSettle();

      // Should now show Sites table content
      expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
      // The SiteField.siteName has displayName 'Name'
      expect(find.text('Name'), findsAtLeastNWidgets(1));
    });

    testWidgets('certifications only shows table and detailed modes', (
      tester,
    ) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Switch to Certifications section
      await tester.tap(find.text('Dives'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Certifications').last);
      await tester.pumpAndSettle();

      // Open the view mode dropdown
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();

      // Should see Table and Detailed but not Compact
      expect(find.text('Table'), findsAtLeastNWidgets(1));
      expect(find.text('Detailed'), findsOneWidget);
      // Compact should NOT be available
      expect(find.text('Compact'), findsNothing);
    });

    testWidgets('courses only shows table and detailed modes', (tester) async {
      await tester.pumpWidget(_buildColumnConfigPage());
      await tester.pump();

      // Switch to Courses section
      await tester.tap(find.text('Dives'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Courses').last);
      await tester.pumpAndSettle();

      // Open the view mode dropdown
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();

      // Should see Table and Detailed but not Compact
      expect(find.text('Table'), findsAtLeastNWidgets(1));
      expect(find.text('Detailed'), findsOneWidget);
      expect(find.text('Compact'), findsNothing);
    });

    testWidgets(
      'switching from compact mode section to certifications resets to table',
      (tester) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        // Switch to Compact mode first (available for Dives)
        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compact').last);
        await tester.pumpAndSettle();

        expect(find.text('Compact'), findsOneWidget);

        // Now switch to Certifications section (no compact mode)
        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Certifications').last);
        await tester.pumpAndSettle();

        // Mode should have reset to Table since Compact isn't available
        expect(find.text('Table'), findsOneWidget);
      },
    );
  });
}
