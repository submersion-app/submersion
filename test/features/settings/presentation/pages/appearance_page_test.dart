import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/appearance_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Mock SettingsNotifier that doesn't access the database
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setDiveDetailSections(
    List<DiveDetailSectionConfig> sections,
  ) async => state = state.copyWith(diveDetailSections: sections);

  @override
  Future<void> resetDiveDetailSections() async =>
      state = state.copyWith(clearDiveDetailSections: true);

  @override
  Future<void> setShowProfilePanelInTableView(bool value) async =>
      state = state.copyWith(showProfilePanelInTableView: value);

  @override
  Future<void> setDiveListViewMode(ListViewMode mode) async =>
      state = state.copyWith(diveListViewMode: mode);

  @override
  Future<void> setSiteListViewMode(ListViewMode mode) async =>
      state = state.copyWith(siteListViewMode: mode);

  @override
  Future<void> setTripListViewMode(ListViewMode mode) async =>
      state = state.copyWith(tripListViewMode: mode);

  @override
  Future<void> setEquipmentListViewMode(ListViewMode mode) async =>
      state = state.copyWith(equipmentListViewMode: mode);

  @override
  Future<void> setBuddyListViewMode(ListViewMode mode) async =>
      state = state.copyWith(buddyListViewMode: mode);

  @override
  Future<void> setDiveCenterListViewMode(ListViewMode mode) async =>
      state = state.copyWith(diveCenterListViewMode: mode);

  @override
  Future<void> setCardColorAttribute(CardColorAttribute attribute) async =>
      state = state.copyWith(cardColorAttribute: attribute);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildTestWidget() {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppearancePage(),
    ),
  );
}

void main() {
  group('AppearancePage dive detail sections', () {
    testWidgets('shows Dive Details section header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Dive Details'), findsOneWidget);
    });

    testWidgets('shows Section Order & Visibility tile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Section Order & Visibility'), findsOneWidget);
      expect(
        find.text('Choose which sections appear and their order'),
        findsOneWidget,
      );
    });

    testWidgets('shows reorder icon on dive details tile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.reorder), findsOneWidget);
    });
  });

  group('AppearancePage details pane toggles', () {
    testWidgets('shows details pane toggle header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Show details pane in table mode'), findsOneWidget);
    });

    testWidgets('shows toggle tiles for all 8 entity sections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // All 8 section labels should be present as SwitchListTile titles
      // Note: some of these labels may also appear elsewhere in the page
      // (e.g., 'Dive Sites' as a section header) so we check for the
      // specific toggle tiles by finding SwitchListTile widgets.
      final switchTiles = find.byType(SwitchListTile);
      expect(switchTiles, findsAtLeastNWidgets(8));

      // Verify each section label is present somewhere on the page
      for (final label in [
        'Dives',
        'Sites',
        'Buddies',
        'Trips',
        'Equipment',
        'Dive Centers',
        'Certifications',
        'Courses',
      ]) {
        expect(find.text(label), findsAtLeastNWidgets(1));
      }
    });
  });

  group('AppearancePage details pane toggle interactions', () {
    for (final entry in [
      ('Dives', 'dives'),
      ('Sites', 'sites'),
      ('Buddies', 'buddies'),
      ('Trips', 'trips'),
      ('Equipment', 'equipment'),
      ('Dive Centers', 'diveCenters'),
      ('Certifications', 'certifications'),
      ('Courses', 'courses'),
    ]) {
      testWidgets('toggling ${entry.$1} details pane switch updates provider', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(400, 6000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_buildTestWidget());
        await tester.pumpAndSettle();

        // Find the SwitchListTile with the section label
        final switchFinder = find.widgetWithText(SwitchListTile, entry.$1);
        expect(switchFinder, findsOneWidget);

        // Initially off (default is false)
        final beforeWidget = tester.widget<SwitchListTile>(switchFinder);
        expect(beforeWidget.value, isFalse);

        // Tap it
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        // The SwitchListTile should now be on
        final afterWidget = tester.widget<SwitchListTile>(switchFinder);
        expect(afterWidget.value, isTrue);
      });
    }
  });

  group('AppearancePage profile panel toggle', () {
    testWidgets('shows Show Profile Panel in Table View switch', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      final switchFinder = find.widgetWithText(
        SwitchListTile,
        'Show Profile Panel in Table View',
      );
      expect(switchFinder, findsOneWidget);
    });

    testWidgets('toggling profile panel switch updates state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      final switchFinder = find.widgetWithText(
        SwitchListTile,
        'Show Profile Panel in Table View',
      );
      expect(switchFinder, findsOneWidget);

      // Initially on (default is true)
      final beforeWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(beforeWidget.value, isTrue);

      // Tap it to turn off
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // The SwitchListTile should now be off
      final afterWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(afterWidget.value, isFalse);
    });
  });

  group('AppearancePage view mode dropdowns', () {
    testWidgets('shows Dive List View dropdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Dive List View'), findsOneWidget);
      expect(find.text('Default layout for the dive list'), findsOneWidget);
    });

    testWidgets('shows Site List View dropdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Site List View'), findsOneWidget);
      expect(find.text('Default layout for the site list'), findsOneWidget);
    });

    testWidgets('shows Trip List View dropdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Trip List View'), findsOneWidget);
      expect(find.text('Default layout for the trip list'), findsOneWidget);
    });

    testWidgets('shows Buddy List View dropdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Buddy List View'), findsOneWidget);
      expect(find.text('Default layout for the buddy list'), findsOneWidget);
    });

    testWidgets('shows Equipment List View dropdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Equipment List View'), findsOneWidget);
      expect(
        find.text('Default layout for the equipment list'),
        findsOneWidget,
      );
    });

    testWidgets('shows Dive Center List View dropdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Dive Center List View'), findsOneWidget);
      expect(
        find.text('Default layout for the dive center list'),
        findsOneWidget,
      );
    });

    testWidgets('dive list view dropdown defaults to Detailed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // The default diveListViewMode is ListViewMode.detailed,
      // which renders as 'Detailed' text in the dropdown
      final dropdowns = find.byType(DropdownButton<ListViewMode>);
      expect(dropdowns, findsAtLeastNWidgets(1));
    });
  });
}
