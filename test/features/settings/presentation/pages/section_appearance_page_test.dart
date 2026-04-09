import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/settings/presentation/pages/section_appearance_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Widget _buildTestWidget(
  String sectionKey, {
  bool embedded = false,
  VoidCallback? onColumnConfigTap,
  List<dynamic>? overrides,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ...?overrides?.cast(),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionAppearancePage(
        sectionKey: sectionKey,
        embedded: embedded,
        onColumnConfigTap: onColumnConfigTap,
      ),
    ),
  );
}

void main() {
  group('SectionAppearancePage - Dives section', () {
    testWidgets('shows all 5 section headers and dive-specific settings', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives'));
      await tester.pumpAndSettle();

      // 5 section headers: List View, Cards, Table Mode, Dive Profile,
      // Dive Details
      expect(find.text('List View'), findsOneWidget);
      expect(find.text('Cards'), findsOneWidget);
      expect(find.text('Table Mode'), findsOneWidget);
      expect(find.text('Dive Profile'), findsOneWidget);
      expect(find.text('Dive Details'), findsOneWidget);

      // Dive-specific settings
      expect(find.text('Show Profile Panel in Table View'), findsOneWidget);
      expect(find.text('Show data source badges'), findsOneWidget);
    });
  });

  group('SectionAppearancePage - Sites section', () {
    testWidgets(
      'shows List View, Cards, Table Mode but NOT Dive Profile or Dive Details',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 4000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_buildTestWidget('sites'));
        await tester.pumpAndSettle();

        expect(find.text('List View'), findsOneWidget);
        expect(find.text('Cards'), findsOneWidget);
        expect(find.text('Table Mode'), findsOneWidget);

        // Should NOT have dive-specific sections
        expect(find.text('Dive Profile'), findsNothing);
        expect(find.text('Dive Details'), findsNothing);
      },
    );
  });

  group('SectionAppearancePage - Buddies section', () {
    testWidgets('shows List View and Table Mode only (no Cards)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('buddies'));
      await tester.pumpAndSettle();

      expect(find.text('List View'), findsOneWidget);
      expect(find.text('Table Mode'), findsOneWidget);

      // No Cards section for buddies
      expect(find.text('Cards'), findsNothing);
    });
  });

  group('SectionAppearancePage - Certifications section', () {
    testWidgets('shows View Mode and List Fields', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('certifications'));
      await tester.pumpAndSettle();

      // Should have the View Mode dropdown
      expect(find.text('List View'), findsOneWidget);
      expect(find.byType(DropdownButton<ListViewMode>), findsOneWidget);

      // Should have the list fields navigation tile
      expect(find.text('Certification List Fields'), findsOneWidget);
    });
  });

  group('SectionAppearancePage - Embedded mode', () {
    testWidgets('omits Scaffold AppBar when embedded', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives', embedded: true));
      await tester.pumpAndSettle();

      // In embedded mode, there should be no AppBar
      expect(find.byType(AppBar), findsNothing);

      // But the content should still be present
      expect(find.text('List View'), findsOneWidget);
    });
  });

  group('SectionAppearancePage - Invalid section', () {
    testWidgets('returns SizedBox.shrink for unknown sectionKey', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget('nonexistent'));
      await tester.pumpAndSettle();

      // Should render nothing meaningful
      expect(find.text('List View'), findsNothing);
      expect(find.byType(ListView), findsNothing);
    });
  });

  group('SectionAppearancePage - Non-embedded mode', () {
    testWidgets('shows Scaffold with AppBar when not embedded', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Dives Appearance'), findsOneWidget);
    });

    testWidgets('shows correct AppBar title for sites', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('sites'));
      await tester.pumpAndSettle();

      expect(find.text('Dive Sites Appearance'), findsOneWidget);
    });
  });

  group('SectionAppearancePage - View mode dropdown', () {
    testWidgets('shows correct dropdown items for dives (3 modes)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives'));
      await tester.pumpAndSettle();

      // Open the dropdown
      await tester.tap(find.byType(DropdownButton<ListViewMode>));
      await tester.pumpAndSettle();

      // All three view modes should appear
      expect(find.text('Detailed'), findsWidgets);
      expect(find.text('Compact'), findsWidgets);
      expect(find.text('Table'), findsWidgets);
    });

    testWidgets('certifications section shows only detailed and table', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('certifications'));
      await tester.pumpAndSettle();

      // Open the dropdown
      await tester.tap(find.byType(DropdownButton<ListViewMode>));
      await tester.pumpAndSettle();

      expect(find.text('Detailed'), findsWidgets);
      expect(find.text('Table'), findsWidgets);
      // Compact should NOT be available for certifications
      expect(find.text('Compact'), findsNothing);
    });

    testWidgets('changing dropdown updates view mode for dives', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives'));
      await tester.pumpAndSettle();

      // Open dropdown and select Table
      await tester.tap(find.byType(DropdownButton<ListViewMode>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Table').last);
      await tester.pumpAndSettle();

      // The dropdown should now show Table as selected
      expect(
        find.descendant(
          of: find.byType(DropdownButton<ListViewMode>),
          matching: find.text('Table'),
        ),
        findsOneWidget,
      );
    });
  });

  group('SectionAppearancePage - List fields tile', () {
    testWidgets('calls onColumnConfigTap when provided', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var tapped = false;
      await tester.pumpWidget(
        _buildTestWidget('dives', onColumnConfigTap: () => tapped = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dive List Fields'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('shows correct label per section', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('equipment'));
      await tester.pumpAndSettle();

      expect(find.text('Equipment List Fields'), findsOneWidget);
    });
  });

  group('SectionAppearancePage - Details pane toggle', () {
    testWidgets('shows details pane switch for all sections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('trips'));
      await tester.pumpAndSettle();

      expect(find.text('Show Details Pane'), findsOneWidget);
      expect(find.text('Display details pane alongside table'), findsOneWidget);
    });

    testWidgets('toggling details pane switch changes switch value', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Use buddies which has only 1 SwitchListTile (details pane only)
      await tester.pumpWidget(_buildTestWidget('buddies'));
      await tester.pumpAndSettle();

      final switchFinder = find.byType(SwitchListTile);
      expect(switchFinder, findsOneWidget);

      var switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isFalse);

      // Toggle it on
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isTrue);
    });
  });

  group('SectionAppearancePage - Dive table extras', () {
    testWidgets('shows profile panel and data source badge switches', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives'));
      await tester.pumpAndSettle();

      expect(find.text('Show Profile Panel in Table View'), findsOneWidget);
      expect(find.text('Show data source badges'), findsOneWidget);
    });

    testWidgets('table extras not shown for non-dive sections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('sites'));
      await tester.pumpAndSettle();

      expect(find.text('Show Profile Panel in Table View'), findsNothing);
      expect(find.text('Show data source badges'), findsNothing);
    });
  });

  group('SectionAppearancePage - Dive cards settings', () {
    testWidgets('shows card color attribute dropdown for dives', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives'));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButton<CardColorAttribute>), findsOneWidget);
    });

    testWidgets('gradient picker hidden when card color is none', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives'));
      await tester.pumpAndSettle();

      // Default is CardColorAttribute.none, so GradientPresetPicker
      // should not be present
      expect(find.text('Ocean'), findsNothing);
    });

    testWidgets('shows map background switch for dive cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.map), findsWidgets);
    });
  });

  group('SectionAppearancePage - Site cards settings', () {
    testWidgets('shows map background switch for site cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('sites'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.map), findsWidgets);
    });
  });

  group('SectionAppearancePage - Dive profile settings', () {
    testWidgets('shows all dive profile settings', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives'));
      await tester.pumpAndSettle();

      // Right Y-axis metric dropdown
      expect(find.byIcon(Icons.show_chart), findsOneWidget);

      // Max depth marker switch
      expect(find.byIcon(Icons.vertical_align_bottom), findsOneWidget);

      // Gas switch markers switch
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);

      // Visible metrics navigation tile
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('profile settings not shown for non-dive sections', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('buddies'));
      await tester.pumpAndSettle();

      expect(find.text('Dive Profile'), findsNothing);
      expect(find.byIcon(Icons.vertical_align_bottom), findsNothing);
    });
  });

  group('SectionAppearancePage - Dive details settings', () {
    testWidgets('shows dive details navigation tile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.reorder), findsOneWidget);
    });

    testWidgets('dive details section not shown for non-dive sections', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('equipment'));
      await tester.pumpAndSettle();

      expect(find.text('Dive Details'), findsNothing);
      expect(find.byIcon(Icons.reorder), findsNothing);
    });
  });

  group('SectionAppearancePage - All 8 sections render', () {
    for (final key in [
      'dives',
      'sites',
      'buddies',
      'trips',
      'equipment',
      'diveCenters',
      'certifications',
      'courses',
    ]) {
      testWidgets('$key section renders without errors', (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 4000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_buildTestWidget(key));
        await tester.pumpAndSettle();

        // All sections should show List View and Table Mode
        expect(find.text('List View'), findsOneWidget);
        expect(find.text('Table Mode'), findsOneWidget);
      });
    }
  });

  group('SectionAppearancePage - View mode for certifications/courses', () {
    testWidgets('certifications uses runtime provider', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildTestWidget(
          'certifications',
          overrides: [
            certificationListViewModeProvider.overrideWith(
              (_) => ListViewMode.table,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Should show Table as current value
      expect(
        find.descendant(
          of: find.byType(DropdownButton<ListViewMode>),
          matching: find.text('Table'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('courses uses runtime provider', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildTestWidget(
          'courses',
          overrides: [
            courseListViewModeProvider.overrideWith((_) => ListViewMode.table),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(DropdownButton<ListViewMode>),
          matching: find.text('Table'),
        ),
        findsOneWidget,
      );
    });
  });

  group('SectionAppearancePage - Enabled metrics count', () {
    testWidgets('shows metrics count in dives profile section', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives'));
      await tester.pumpAndSettle();

      // Default settings have some metrics enabled. The exact count depends
      // on default AppSettings. Find the pattern "X of 18"
      expect(find.textContaining('of 18'), findsOneWidget);
    });
  });
}
