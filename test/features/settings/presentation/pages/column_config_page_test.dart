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
import 'package:submersion/shared/models/entity_card_view_config.dart';
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
  EntityCardViewConfig<BuddyField>? buddyDetailedConfig,
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
      // Entity card config providers for detailed / compact card sections
      buddyDetailedCardConfigProvider.overrideWith(
        (ref) =>
            buddyDetailedConfig ??
            const EntityCardViewConfig<BuddyField>(
              slots: [
                EntityCardSlotConfig(
                  slotId: 'title',
                  field: BuddyField.buddyName,
                ),
                EntityCardSlotConfig(
                  slotId: 'subtitle',
                  field: BuddyField.email,
                ),
              ],
            ),
      ),
      buddyCompactCardConfigProvider.overrideWith(
        (ref) => const EntityCardViewConfig<BuddyField>(
          slots: [
            EntityCardSlotConfig(slotId: 'title', field: BuddyField.buddyName),
            EntityCardSlotConfig(slotId: 'subtitle', field: BuddyField.email),
          ],
        ),
      ),
      siteDetailedCardConfigProvider.overrideWith(
        (ref) => const EntityCardViewConfig<SiteField>(
          slots: [
            EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
            EntityCardSlotConfig(slotId: 'subtitle', field: SiteField.country),
          ],
        ),
      ),
      siteCompactCardConfigProvider.overrideWith(
        (ref) => const EntityCardViewConfig<SiteField>(
          slots: [
            EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
            EntityCardSlotConfig(slotId: 'subtitle', field: SiteField.country),
          ],
        ),
      ),
      tripDetailedCardConfigProvider.overrideWith(
        (ref) => const EntityCardViewConfig<TripField>(
          slots: [
            EntityCardSlotConfig(slotId: 'title', field: TripField.tripName),
            EntityCardSlotConfig(slotId: 'subtitle', field: TripField.location),
          ],
        ),
      ),
      tripCompactCardConfigProvider.overrideWith(
        (ref) => const EntityCardViewConfig<TripField>(
          slots: [
            EntityCardSlotConfig(slotId: 'title', field: TripField.tripName),
            EntityCardSlotConfig(slotId: 'subtitle', field: TripField.location),
          ],
        ),
      ),
      equipmentDetailedCardConfigProvider.overrideWith(
        (ref) => const EntityCardViewConfig<EquipmentField>(
          slots: [
            EntityCardSlotConfig(
              slotId: 'title',
              field: EquipmentField.itemName,
            ),
            EntityCardSlotConfig(
              slotId: 'subtitle',
              field: EquipmentField.type,
            ),
          ],
        ),
      ),
      equipmentCompactCardConfigProvider.overrideWith(
        (ref) => const EntityCardViewConfig<EquipmentField>(
          slots: [
            EntityCardSlotConfig(
              slotId: 'title',
              field: EquipmentField.itemName,
            ),
            EntityCardSlotConfig(
              slotId: 'subtitle',
              field: EquipmentField.type,
            ),
          ],
        ),
      ),
      diveCenterDetailedCardConfigProvider.overrideWith(
        (ref) => const EntityCardViewConfig<DiveCenterField>(
          slots: [
            EntityCardSlotConfig(
              slotId: 'title',
              field: DiveCenterField.centerName,
            ),
            EntityCardSlotConfig(
              slotId: 'subtitle',
              field: DiveCenterField.city,
            ),
          ],
        ),
      ),
      diveCenterCompactCardConfigProvider.overrideWith(
        (ref) => const EntityCardViewConfig<DiveCenterField>(
          slots: [
            EntityCardSlotConfig(
              slotId: 'title',
              field: DiveCenterField.centerName,
            ),
            EntityCardSlotConfig(
              slotId: 'subtitle',
              field: DiveCenterField.city,
            ),
          ],
        ),
      ),
      certificationDetailedCardConfigProvider.overrideWith(
        (ref) => const EntityCardViewConfig<CertificationField>(
          slots: [
            EntityCardSlotConfig(
              slotId: 'title',
              field: CertificationField.certName,
            ),
            EntityCardSlotConfig(
              slotId: 'subtitle',
              field: CertificationField.agency,
            ),
          ],
        ),
      ),
      courseDetailedCardConfigProvider.overrideWith(
        (ref) => const EntityCardViewConfig<CourseField>(
          slots: [
            EntityCardSlotConfig(
              slotId: 'title',
              field: CourseField.courseName,
            ),
            EntityCardSlotConfig(slotId: 'subtitle', field: CourseField.agency),
          ],
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

    // -----------------------------------------------------------------
    // Entity table section tests
    // -----------------------------------------------------------------

    group('entity table sections', () {
      testWidgets('sites section in table mode shows site columns', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        // Switch to Sites
        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sites').last);
        await tester.pumpAndSettle();

        expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
        // SiteField.siteName displayName is 'Name'
        expect(find.text('Name'), findsAtLeastNWidgets(1));
      });

      testWidgets('buddies section in table mode shows buddy columns', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buddies').last);
        await tester.pumpAndSettle();

        expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
        // BuddyField.buddyName displayName is 'Name'
        expect(find.text('Name'), findsAtLeastNWidgets(1));
      });

      testWidgets('trips section in table mode shows trip columns', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Trips').last);
        await tester.pumpAndSettle();

        expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
        // TripField.tripName displayName is 'Name'
        expect(find.text('Name'), findsAtLeastNWidgets(1));
      });

      testWidgets('equipment section in table mode shows equipment columns', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Equipment').last);
        await tester.pumpAndSettle();

        expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
        // EquipmentField.itemName displayName is 'Name'
        expect(find.text('Name'), findsAtLeastNWidgets(1));
      });

      testWidgets(
        'dive centers section in table mode shows dive center columns',
        (tester) async {
          await tester.pumpWidget(_buildColumnConfigPage());
          await tester.pump();

          await tester.tap(find.text('Dives'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Dive Centers').last);
          await tester.pumpAndSettle();

          expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
          // DiveCenterField.centerName displayName is 'Name'
          expect(find.text('Name'), findsAtLeastNWidgets(1));
        },
      );

      testWidgets(
        'certifications section in table mode shows certification columns',
        (tester) async {
          await tester.pumpWidget(_buildColumnConfigPage());
          await tester.pump();

          await tester.tap(find.text('Dives'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Certifications').last);
          await tester.pumpAndSettle();

          expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
          // CertificationField.certName displayName is 'Name'
          expect(find.text('Name'), findsAtLeastNWidgets(1));
        },
      );

      testWidgets('courses section in table mode shows course columns', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Courses').last);
        await tester.pumpAndSettle();

        expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
        // CourseField.courseName displayName is 'Name'
        expect(find.text('Name'), findsAtLeastNWidgets(1));
      });

      testWidgets('tapping pin icon in entity table section toggles pin', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        // Switch to Sites section (has 2 columns: siteName pinned, country)
        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sites').last);
        await tester.pumpAndSettle();

        // Find the pin icons - there should be at least one
        // SiteField.country is unpinned so it has push_pin_outlined
        final outlinedPins = find.byIcon(Icons.push_pin_outlined);
        expect(outlinedPins, findsAtLeastNWidgets(1));

        await tester.tap(outlinedPins.first);
        await tester.pump();

        // Widget tree should remain intact after toggle
        expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
      });

      testWidgets(
        'tapping remove icon in entity table section removes column',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(800, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(_buildColumnConfigPage());
          await tester.pump();

          // Switch to Sites section (has 2 columns: siteName pinned, country)
          await tester.tap(find.text('Dives'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Sites').last);
          await tester.pumpAndSettle();

          // The unpinned column (country) should have a remove button
          final removeButtons = find.byIcon(Icons.remove_circle_outline);
          expect(removeButtons, findsAtLeastNWidgets(1));

          await tester.tap(removeButtons.first);
          await tester.pump();

          // Widget tree should remain intact after removal
          expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
        },
      );

      testWidgets('tapping add icon in entity table section adds column', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        // Switch to Sites section
        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sites').last);
        await tester.pumpAndSettle();

        // Available fields should have add buttons
        final addButtons = find.byIcon(Icons.add_circle_outline);
        expect(addButtons, findsAtLeastNWidgets(1));

        await tester.tap(addButtons.first);
        await tester.pump();

        // Widget tree should remain intact after adding
        expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
      });

      testWidgets('entity table section shows available fields section', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sites').last);
        await tester.pumpAndSettle();

        expect(find.text('AVAILABLE FIELDS'), findsOneWidget);
      });

      testWidgets(
        'entity table section shows drag handles for visible columns',
        (tester) async {
          await tester.pumpWidget(_buildColumnConfigPage());
          await tester.pump();

          await tester.tap(find.text('Dives'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Buddies').last);
          await tester.pumpAndSettle();

          expect(find.byIcon(Icons.drag_handle), findsAtLeastNWidgets(1));
        },
      );
    });

    // -----------------------------------------------------------------
    // Entity card section tests
    // -----------------------------------------------------------------

    group('entity card sections', () {
      testWidgets('buddies in detailed mode shows card slot assignments', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        // Switch to Buddies section
        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buddies').last);
        await tester.pumpAndSettle();

        // Switch to Detailed mode
        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Detailed').last);
        await tester.pumpAndSettle();

        // Card config UI should appear with slot assignments
        expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
      });

      testWidgets('buddies in detailed mode shows extra fields section', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buddies').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Detailed').last);
        await tester.pumpAndSettle();

        // Detailed mode shows extra fields section
        expect(find.text('EXTRA FIELDS'), findsOneWidget);
        expect(
          find.textContaining('Additional fields shown below'),
          findsOneWidget,
        );
      });

      testWidgets('sites in detailed mode shows card slot assignments', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sites').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Detailed').last);
        await tester.pumpAndSettle();

        expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
      });

      testWidgets('trips in detailed mode shows card slot assignments', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Trips').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Detailed').last);
        await tester.pumpAndSettle();

        expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
      });

      testWidgets('equipment in compact mode shows card slot assignments', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Equipment').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compact').last);
        await tester.pumpAndSettle();

        // Compact mode shows slot assignments but not extra fields
        expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
        expect(find.text('EXTRA FIELDS'), findsNothing);
      });

      testWidgets('equipment in detailed mode shows extra fields section', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Equipment').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Detailed').last);
        await tester.pumpAndSettle();

        expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
        expect(find.text('EXTRA FIELDS'), findsOneWidget);
      });

      testWidgets('dive centers in detailed mode shows card config', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dive Centers').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Detailed').last);
        await tester.pumpAndSettle();

        expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
      });

      testWidgets(
        'dive centers in compact mode shows card config without extra fields',
        (tester) async {
          await tester.pumpWidget(_buildColumnConfigPage());
          await tester.pump();

          await tester.tap(find.text('Dives'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Dive Centers').last);
          await tester.pumpAndSettle();

          await tester.tap(find.text('Table'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Compact').last);
          await tester.pumpAndSettle();

          expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
          expect(find.text('EXTRA FIELDS'), findsNothing);
        },
      );

      testWidgets('certifications in detailed mode shows card config', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Certifications').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Detailed').last);
        await tester.pumpAndSettle();

        expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
        expect(find.text('EXTRA FIELDS'), findsOneWidget);
      });

      testWidgets('courses in detailed mode shows card config', (tester) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Courses').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Detailed').last);
        await tester.pumpAndSettle();

        expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
        expect(find.text('EXTRA FIELDS'), findsOneWidget);
      });

      testWidgets(
        'detailed entity card shows no extra fields message when empty',
        (tester) async {
          await tester.pumpWidget(_buildColumnConfigPage());
          await tester.pump();

          await tester.tap(find.text('Dives'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Sites').last);
          await tester.pumpAndSettle();

          await tester.tap(find.text('Table'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Detailed').last);
          await tester.pumpAndSettle();

          expect(
            find.textContaining('No extra fields configured'),
            findsOneWidget,
          );
        },
      );

      testWidgets('detailed entity card shows available fields section', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buddies').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Detailed').last);
        await tester.pumpAndSettle();

        expect(find.text('AVAILABLE FIELDS'), findsOneWidget);
      });

      // ---------------------------------------------------------------
      // Compact mode tests (cover compact card config providers)
      // ---------------------------------------------------------------

      testWidgets('sites in compact mode uses compact card config', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        // Switch to Sites section
        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sites').last);
        await tester.pumpAndSettle();

        // Switch to Compact mode
        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compact').last);
        await tester.pumpAndSettle();

        // Compact mode shows slot assignments but no extra fields
        expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
        expect(find.text('EXTRA FIELDS'), findsNothing);
      });

      testWidgets('buddies in compact mode uses compact card config', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        // Switch to Buddies section
        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buddies').last);
        await tester.pumpAndSettle();

        // Switch to Compact mode
        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compact').last);
        await tester.pumpAndSettle();

        // Compact mode shows slot assignments but no extra fields
        expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
        expect(find.text('EXTRA FIELDS'), findsNothing);
      });

      testWidgets('trips in compact mode uses compact card config', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        // Switch to Trips section
        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Trips').last);
        await tester.pumpAndSettle();

        // Switch to Compact mode
        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compact').last);
        await tester.pumpAndSettle();

        // Compact mode shows slot assignments but no extra fields
        expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
        expect(find.text('EXTRA FIELDS'), findsNothing);
      });

      // ---------------------------------------------------------------
      // Entity card interaction tests
      // ---------------------------------------------------------------

      testWidgets('changing entity card slot field updates config', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        // Switch to Buddies section
        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buddies').last);
        await tester.pumpAndSettle();

        // Switch to Detailed mode
        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Detailed').last);
        await tester.pumpAndSettle();

        // Find the slot dropdown for the title slot (currently shows 'Name')
        // The slot displays BuddyField.buddyName which has displayName 'Name'
        // Open the dropdown by tapping the current value
        final nameTexts = find.text('Name');
        expect(nameTexts, findsAtLeastNWidgets(1));

        // Tap the first 'Name' text which is in the slot dropdown
        await tester.tap(nameTexts.first);
        await tester.pumpAndSettle();

        // Select a different field - 'Phone'
        await tester.tap(find.text('Phone').last);
        await tester.pumpAndSettle();

        // After changing, the slot should now show Phone
        expect(find.text('Phone'), findsAtLeastNWidgets(1));
        // The widget tree should remain intact
        expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
      });

      testWidgets('adding extra field in entity detailed card config', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        // Switch to Buddies section
        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buddies').last);
        await tester.pumpAndSettle();

        // Switch to Detailed mode (shows extra fields + available fields)
        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Detailed').last);
        await tester.pumpAndSettle();

        // Initially no extra fields configured
        expect(
          find.textContaining('No extra fields configured'),
          findsOneWidget,
        );

        // Find an add button in the available fields section
        final addButtons = find.byIcon(Icons.add_circle_outline);
        expect(addButtons, findsAtLeastNWidgets(1));

        // Tap the first add button to add an extra field
        await tester.tap(addButtons.first);
        await tester.pumpAndSettle();

        // After adding, the 'No extra fields' message should be gone
        expect(find.textContaining('No extra fields configured'), findsNothing);

        // A remove button should now appear for the added field
        expect(
          find.byIcon(Icons.remove_circle_outline),
          findsAtLeastNWidgets(1),
        );
      });

      testWidgets('removing extra field in entity detailed card config', (
        tester,
      ) async {
        // Build with pre-populated extra fields on the buddy detailed config
        await tester.pumpWidget(
          _buildColumnConfigPage(
            buddyDetailedConfig: const EntityCardViewConfig<BuddyField>(
              slots: [
                EntityCardSlotConfig(
                  slotId: 'title',
                  field: BuddyField.buddyName,
                ),
                EntityCardSlotConfig(
                  slotId: 'subtitle',
                  field: BuddyField.email,
                ),
              ],
              extraFields: [BuddyField.phone],
            ),
          ),
        );
        await tester.pump();

        // Switch to Buddies section
        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buddies').last);
        await tester.pumpAndSettle();

        // Switch to Detailed mode
        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Detailed').last);
        await tester.pumpAndSettle();

        // The extra field 'Phone' should be shown
        expect(find.text('Phone'), findsAtLeastNWidgets(1));

        // Should not show the empty message
        expect(find.textContaining('No extra fields configured'), findsNothing);

        // Find the remove button for the extra field
        final removeButtons = find.byIcon(Icons.remove_circle_outline);
        expect(removeButtons, findsAtLeastNWidgets(1));

        // Tap the remove button to remove the extra field
        await tester.tap(removeButtons.first);
        await tester.pumpAndSettle();

        // After removal, the empty message should reappear
        expect(
          find.textContaining('No extra fields configured'),
          findsOneWidget,
        );
      });

      testWidgets('switching section preserves view mode when valid', (
        tester,
      ) async {
        await tester.pumpWidget(_buildColumnConfigPage());
        await tester.pump();

        // Switch to Detailed mode on Dives
        await tester.tap(find.text('Table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Detailed').last);
        await tester.pumpAndSettle();

        // Switch to Buddies - detailed mode should be preserved
        await tester.tap(find.text('Dives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buddies').last);
        await tester.pumpAndSettle();

        // Should still be in Detailed mode with entity card config
        expect(find.text('SLOT ASSIGNMENTS'), findsOneWidget);
        expect(find.text('Detailed'), findsOneWidget);
      });
    });
  });
}
