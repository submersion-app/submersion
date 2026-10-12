import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/widgets/data_sources_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

const _units = UnitFormatter(AppSettings());

DiveDataSource _makeSource({
  String id = 'src-1',
  String diveId = 'dive-1',
  String? computerId = 'comp-1',
  bool isPrimary = true,
  String? computerName,
  String? computerModel = 'Shearwater Perdix',
  String? computerSerial = 'SN-12345',
  String? sourceFormat = 'SSRF',
  String? sourceFileName = 'dive_log.ssrf',
  double? maxDepth = 30.0,
  double? avgDepth = 18.5,
  int? duration = 3000,
  double? waterTemp = 22.0,
  double? cns = 15.0,
  double? otu,
  String? decoAlgorithm,
  int? gradientFactorLow,
  int? gradientFactorHigh,
  DateTime? entryTime,
  DateTime? exitTime,
  DateTime? importedAt,
  DateTime? createdAt,
}) {
  final now = DateTime(2026, 3, 20, 10, 0);
  return DiveDataSource(
    id: id,
    diveId: diveId,
    computerId: computerId,
    isPrimary: isPrimary,
    computerName: computerName,
    computerModel: computerModel,
    computerSerial: computerSerial,
    sourceFormat: sourceFormat,
    sourceFileName: sourceFileName,
    maxDepth: maxDepth,
    avgDepth: avgDepth,
    duration: duration,
    waterTemp: waterTemp,
    cns: cns,
    otu: otu,
    decoAlgorithm: decoAlgorithm,
    gradientFactorLow: gradientFactorLow,
    gradientFactorHigh: gradientFactorHigh,
    entryTime: entryTime ?? now,
    exitTime: exitTime ?? now.add(const Duration(minutes: 50)),
    importedAt: importedAt ?? now,
    createdAt: createdAt ?? now,
  );
}

void main() {
  group('DataSourcesSection', () {
    testWidgets('shows "Manual Entry" card when no data sources exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: const [],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manual Entry'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    // The creation date and the entry/exit times were hardcoded to a
    // month-first, 12-hour format regardless of the diver's settings (#964).
    testWidgets('manual entry creation date follows the date preference', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: const [],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: const UnitFormatter(
                AppSettings(dateFormat: DateFormatPreference.ddmmyyyy),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Created 20/03/2026'), findsOneWidget);
    });

    testWidgets('source card date and time follow the diver preferences', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [_makeSource()],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: const UnitFormatter(
                AppSettings(
                  dateFormat: DateFormatPreference.ddmmyyyy,
                  timeFormat: TimeFormat.twentyFourHour,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Entry 10:00 renders 24-hour rather than the old hardcoded "10:00 AM".
      expect(find.textContaining('10:00'), findsWidgets);
      expect(find.textContaining('AM'), findsNothing);
      expect(find.textContaining('20/03/2026'), findsWidgets);
    });

    testWidgets('shows single source card with model name and filename', (
      tester,
    ) async {
      final source = _makeSource();

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shearwater Perdix'), findsOneWidget);
      expect(find.text('dive_log.ssrf'), findsOneWidget);
    });

    testWidgets(
      'shows a "Primary" chip and no "Secondary" chip for multi-source dive',
      (tester) async {
        final primary = _makeSource(id: 'src-1', isPrimary: true);
        final secondary = _makeSource(
          id: 'src-2',
          isPrimary: false,
          computerModel: 'Suunto D5',
          computerSerial: 'SN-99999',
        );

        await tester.pumpWidget(
          testApp(
            child: SingleChildScrollView(
              child: DataSourcesSection(
                dataSources: [primary, secondary],
                diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
                diveId: 'dive-1',
                units: _units,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Primary'), findsOneWidget);
        expect(find.text('Secondary'), findsNothing);
      },
    );

    testWidgets('Compare in 3D lives in the header menu for multi-source', (
      tester,
    ) async {
      final primary = _makeSource(id: 'src-1', isPrimary: true);
      final secondary = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerModel: 'Suunto D5',
      );
      var tapped = false;
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [primary, secondary],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              onCompareIn3d: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compare in 3D'), findsNothing);
      await tester.tap(find.byKey(DataSourcesSection.sectionMenuKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compare in 3D'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('Separate combined dives lives in the header menu', (
      tester,
    ) async {
      var separated = false;
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [_makeSource()],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              onSeparate: () => separated = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DataSourcesSection.sectionMenuKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Separate combined dives'));
      await tester.pumpAndSettle();
      expect(separated, isTrue);
      // Opening the menu did not collapse the section.
      expect(find.text('Shearwater Perdix'), findsOneWidget);
    });

    testWidgets('header menu is hidden when no section action applies', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [_makeSource()],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(DataSourcesSection.sectionMenuKey), findsNothing);
    });

    testWidgets('Compare in 3D is not offered for a single source', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [_makeSource()],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              onCompareIn3d: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // A lone source has nothing to compare, so the menu itself is absent.
      expect(find.byKey(DataSourcesSection.sectionMenuKey), findsNothing);
    });

    testWidgets('uses singular "Data Source" header for single source', (
      tester,
    ) async {
      final source = _makeSource();

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Data Source'), findsOneWidget);
    });

    testWidgets('uses plural "Data Sources" header for multi-source', (
      tester,
    ) async {
      final primary = _makeSource(id: 'src-1', isPrimary: true);
      final secondary = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerModel: 'Suunto D5',
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [primary, secondary],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Data Sources'), findsOneWidget);
    });

    testWidgets(
      'shows overflow menu with "Set as primary" for secondary cards only',
      (tester) async {
        final primary = _makeSource(id: 'src-1', isPrimary: true);
        final secondary = _makeSource(
          id: 'src-2',
          isPrimary: false,
          computerModel: 'Suunto D5',
        );

        String? setPrimaryId;

        await tester.pumpWidget(
          testApp(
            child: SingleChildScrollView(
              child: DataSourcesSection(
                dataSources: [primary, secondary],
                diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
                diveId: 'dive-1',
                units: _units,
                onSetPrimary: (id) => setPrimaryId = id,
                onSplit: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the overflow menu buttons (PopupMenuButton uses Icons.more_vert)
        // Both cards should have overflow menus
        final menuButtons = find.byIcon(Icons.more_vert);
        expect(menuButtons, findsNWidgets(2));

        // Tap the secondary card's overflow menu (second one)
        await tester.tap(menuButtons.last);
        await tester.pumpAndSettle();

        // "Set as primary" should appear for secondary card
        expect(find.text('Set as primary'), findsOneWidget);

        // Tap "Set as primary"
        await tester.tap(find.text('Set as primary'));
        await tester.pumpAndSettle();

        expect(setPrimaryId, equals('src-2'));
      },
    );

    testWidgets('primary card overflow menu does not show "Set as primary"', (
      tester,
    ) async {
      final primary = _makeSource(id: 'src-1', isPrimary: true);
      final secondary = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerModel: 'Suunto D5',
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [primary, secondary],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              onSetPrimary: (_) {},
              onSplit: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the primary card's overflow menu (first one)
      final menuButtons = find.byIcon(Icons.more_vert);
      await tester.tap(menuButtons.first);
      await tester.pumpAndSettle();

      // "Set as primary" should NOT appear for primary card
      expect(find.text('Set as primary'), findsNothing);
      // "Split into separate dive" should still appear
      expect(find.text('Split into separate dive'), findsOneWidget);
    });

    testWidgets(
      'tap-to-view: shows "Viewing" badge when viewedSourceId matches',
      (tester) async {
        final primary = _makeSource(id: 'src-1', isPrimary: true);
        final secondary = _makeSource(
          id: 'src-2',
          isPrimary: false,
          computerModel: 'Suunto D5',
        );

        await tester.pumpWidget(
          testApp(
            child: SingleChildScrollView(
              child: DataSourcesSection(
                dataSources: [primary, secondary],
                diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
                diveId: 'dive-1',
                units: _units,
                viewedSourceId: 'src-2',
                onTapSource: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Viewing'), findsOneWidget);
        // The primary card keeps its chip; Viewing no longer replaces it.
        expect(find.text('Primary'), findsOneWidget);
      },
    );

    testWidgets('viewing the primary source shows both chips on one card', (
      tester,
    ) async {
      final primary = _makeSource(id: 'src-1', isPrimary: true);
      final secondary = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerModel: 'Suunto D5',
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [primary, secondary],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              viewedSourceId: 'src-1',
              onTapSource: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(DataSourcesSection.cardKey('src-1'));
      expect(
        find.descendant(of: card, matching: find.text('Primary')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Viewing')),
        findsOneWidget,
      );
    });

    testWidgets('the viewed card gets a tinted background, others do not', (
      tester,
    ) async {
      final primary = _makeSource(id: 'src-1', isPrimary: true);
      final secondary = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerModel: 'Suunto D5',
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [primary, secondary],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              viewedSourceId: 'src-2',
              onTapSource: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Color? cardColor(String id) => tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byKey(DataSourcesSection.cardKey(id)),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;
      final scheme = Theme.of(
        tester.element(find.byType(DataSourcesSection)),
      ).colorScheme;
      expect(cardColor('src-2'), scheme.surfaceContainerHighest);
      expect(cardColor('src-1'), isNot(scheme.surfaceContainerHighest));
    });

    testWidgets(
      'manual entry card shows "Manual" badge for single manual dive',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            child: SingleChildScrollView(
              child: DataSourcesSection(
                dataSources: const [],
                diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
                diveId: 'dive-1',
                units: _units,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Manual'), findsOneWidget);
      },
    );

    testWidgets('shows metrics row with max depth, duration, temp, CNS', (
      tester,
    ) async {
      final source = _makeSource(
        maxDepth: 30.0,
        duration: 3000,
        waterTemp: 22.0,
        cns: 15.0,
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify labels are present
      expect(find.text('Max Depth'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Water Temp'), findsOneWidget);
      expect(find.text('CNS'), findsOneWidget);
    });

    testWidgets('multi-source dive shows metrics in the table only', (
      tester,
    ) async {
      final primary = _makeSource(id: 'src-1', isPrimary: true);
      final secondary = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerModel: 'Suunto D5',
        maxDepth: 31.0,
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [primary, secondary],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // One label per metric: the per-card metrics rows are gone.
      expect(find.text('Max Depth'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Water Temp'), findsOneWidget);
      expect(find.text('CNS'), findsOneWidget);
      // Each source's value appears exactly once, in its table column.
      expect(find.text('30.0m'), findsOneWidget);
      expect(find.text('31.0m'), findsOneWidget);
    });

    testWidgets('comparison table fits two sources at phone width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final primary = _makeSource(
        id: 'src-1',
        isPrimary: true,
        computerName: 'My Perdix',
        computerModel: 'Shearwater Perdix 2',
        decoAlgorithm: 'Buhlmann ZHL-16C',
        gradientFactorLow: 30,
        gradientFactorHigh: 70,
      );
      final secondary = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerName: 'Garmin Descent Mk3i',
        computerModel: 'Garmin Descent Mk3i',
        decoAlgorithm: 'Buhlmann ZHL-16C',
        gradientFactorLow: 40,
        gradientFactorHigh: 85,
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [primary, secondary],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final grid = find.byKey(DataSourcesSection.comparisonGridKey);
      expect(grid, findsOneWidget);
      final rect = tester.getRect(grid);
      expect(rect.right, lessThanOrEqualTo(390));
      // Both source columns are on screen, not scrolled off the right edge.
      expect(
        tester.getRect(find.text('Garmin Descent Mk3i').first).right,
        lessThanOrEqualTo(390),
      );
    });

    testWidgets('comparison table scrolls sideways for three or more sources', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final sources = [
        for (var i = 0; i < 3; i++)
          _makeSource(
            id: 'src-$i',
            isPrimary: i == 0,
            computerModel: 'Computer number $i',
          ),
      ];

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: sources,
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.ancestor(
          of: find.byKey(DataSourcesSection.comparisonGridKey),
          matching: find.byWidgetPredicate(
            (w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.horizontal,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('table keeps rows one source has and drops empty rows', (
      tester,
    ) async {
      final primary = _makeSource(id: 'src-1', isPrimary: true);
      final secondary = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerModel: 'Manual Entry Source',
        maxDepth: null,
        avgDepth: null,
        duration: null,
        waterTemp: null,
        cns: null,
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [primary, secondary],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The primary still has these, so the rows stay with one value each.
      expect(find.text('Max Depth'), findsOneWidget);
      expect(find.text('30.0m'), findsOneWidget);
      // Nobody reports OTU or a deco algorithm, so those rows are dropped.
      expect(find.text('OTU'), findsNothing);
      expect(find.text('Deco Algorithm'), findsNothing);
    });

    testWidgets('shows serial number and source format in details', (
      tester,
    ) async {
      final source = _makeSource(
        computerSerial: 'SN-12345',
        sourceFormat: 'SSRF',
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SN-12345'), findsOneWidget);
      expect(find.text('SSRF'), findsOneWidget);
    });

    testWidgets('no overflow menu on manual entry card (empty sources)', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: const [],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              onSplit: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('onTapSource callback fires when secondary card is tapped', (
      tester,
    ) async {
      final primary = _makeSource(id: 'src-1', isPrimary: true);
      final secondary = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerModel: 'Suunto D5',
      );

      String? tappedId;

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [primary, secondary],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              onTapSource: (id) => tappedId = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the secondary card (find by model name). The comparison grid
      // header also renders the model name, so target the card's copy
      // specifically (rendered after the grid in the widget tree).
      await tester.tap(find.text('Suunto D5').last);
      await tester.pumpAndSettle();

      expect(tappedId, equals('src-2'));
      // Cards are ink wells now, so the tap shows a ripple.
      expect(
        find.descendant(
          of: find.byKey(DataSourcesSection.cardKey('src-2')),
          matching: find.byType(InkWell),
        ),
        findsWidgets,
      );
    });
  });

  group('ManualEntryCard', () {
    testWidgets('shows formatted creation date', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: const [],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Created Mar 20, 2026'), findsOneWidget);
    });

    testWidgets('shows pen (edit) icon', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: const [],
              diveCreatedAt: DateTime(2025, 12, 25, 8, 30),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });
  });

  group('Single source DataSourceCard', () {
    testWidgets('shows formatted metric values', (tester) async {
      final source = _makeSource(
        maxDepth: 30.0,
        duration: 3000, // 50 min
        waterTemp: 22.0,
        cns: 15.0,
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Metric values (metric units: meters, celsius)
      expect(find.text('30.0m'), findsOneWidget);
      expect(find.text('50 min'), findsOneWidget);
      // Temperature: 22C with degree symbol
      expect(find.textContaining('22'), findsWidgets);
      expect(find.text('15%'), findsOneWidget);
    });

    testWidgets('shows import date in details grid', (tester) async {
      final source = _makeSource(importedAt: DateTime(2026, 3, 15, 14, 30));

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Imported'), findsOneWidget);
      expect(find.text('Mar 15, 2026'), findsOneWidget);
    });

    testWidgets('merges entry and exit into one Times row', (tester) async {
      final source = _makeSource(
        entryTime: DateTime(2026, 3, 20, 10, 0),
        exitTime: DateTime(2026, 3, 20, 10, 50),
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Times'), findsOneWidget);
      expect(find.text('10:00 AM–10:50 AM'), findsOneWidget);
      expect(find.text('Entry'), findsNothing);
      expect(find.text('Exit'), findsNothing);
    });

    testWidgets('a lone entry time keeps the Entry label', (tester) async {
      final source = _makeSource(entryTime: DateTime(2026, 3, 20, 10, 0));
      final withoutExit = DiveDataSource(
        id: source.id,
        diveId: source.diveId,
        computerId: source.computerId,
        isPrimary: source.isPrimary,
        computerModel: source.computerModel,
        computerSerial: source.computerSerial,
        sourceFormat: source.sourceFormat,
        entryTime: source.entryTime,
        importedAt: source.importedAt,
        createdAt: source.createdAt,
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [withoutExit],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Entry'), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget);
      expect(find.text('Times'), findsNothing);
    });

    testWidgets('a lone exit time keeps the Exit label', (tester) async {
      final source = _makeSource();
      final withoutEntry = DiveDataSource(
        id: source.id,
        diveId: source.diveId,
        computerId: source.computerId,
        isPrimary: source.isPrimary,
        computerModel: source.computerModel,
        exitTime: DateTime(2026, 3, 20, 10, 50),
        importedAt: source.importedAt,
        createdAt: source.createdAt,
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [withoutEntry],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Exit'), findsOneWidget);
      expect(find.text('10:50 AM'), findsOneWidget);
      expect(find.text('Times'), findsNothing);
      expect(find.text('Entry'), findsNothing);
    });

    testWidgets('file name gets its own labelled row', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [_makeSource()],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('File'), findsOneWidget);
      expect(find.text('dive_log.ssrf'), findsOneWidget);
    });

    testWidgets('does not show badges when single source', (tester) async {
      final source = _makeSource();

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Primary'), findsNothing);
      expect(find.text('Secondary'), findsNothing);
    });

    testWidgets('does not show filename when sourceFileName is null', (
      tester,
    ) async {
      final source = _makeSource(sourceFileName: null);

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('dive_log.ssrf'), findsNothing);
      expect(find.text('File'), findsNothing);
    });

    testWidgets('falls back to the serial when computerModel is null', (
      tester,
    ) async {
      final source = _makeSource(computerModel: null);

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SN-12345'), findsWidgets);
    });

    testWidgets('shows friendly name as header with model as subtitle', (
      tester,
    ) async {
      final source = _makeSource(
        computerName: 'My Perdix',
        computerModel: 'Shearwater Perdix AI',
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Friendly name is the card title; the model appears as a subtitle.
      expect(find.text('My Perdix'), findsOneWidget);
      expect(find.text('Shearwater Perdix AI'), findsOneWidget);
    });

    testWidgets('omits model subtitle when friendly name equals the model', (
      tester,
    ) async {
      final source = _makeSource(
        computerName: 'Shearwater Perdix',
        computerModel: 'Shearwater Perdix',
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Rendered once as the header, not duplicated as a redundant subtitle.
      expect(find.text('Shearwater Perdix'), findsOneWidget);
    });

    testWidgets('omits serial and format labels when fields are null', (
      tester,
    ) async {
      final source = _makeSource(computerSerial: null, sourceFormat: null);

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Serial'), findsNothing);
      expect(find.text('Format'), findsNothing);
    });

    testWidgets('shows watch icon for data source card', (tester) async {
      final source = _makeSource();

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.watch), findsOneWidget);
    });

    testWidgets('no overflow menu when callbacks are null', (tester) async {
      final source = _makeSource();

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              // onSetPrimary and onSplit are null
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    // Issue #2974: the dive detail page always wires both callbacks, but a
    // lone primary reading has no menu entry to show (it is already primary,
    // and split needs two sources). An icon over an empty menu opens nothing.
    testWidgets('no overflow menu for a lone primary source', (tester) async {
      final source = _makeSource();

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              onSetPrimary: (_) {},
              onSplit: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('lone non-primary source still offers "Set as primary"', (
      tester,
    ) async {
      String? setPrimaryId;
      final source = _makeSource(id: 'src-legacy', isPrimary: false);

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              onSetPrimary: (id) => setPrimaryId = id,
              onSplit: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set as primary'));
      await tester.pumpAndSettle();

      expect(setPrimaryId, 'src-legacy');
    });
  });

  group('Multi-source cards', () {
    testWidgets('shows divider between cards', (tester) async {
      final primary = _makeSource(id: 'src-1', isPrimary: true);
      final secondary = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerModel: 'Suunto D5',
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [primary, secondary],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // One below the comparison grid, one between the two cards.
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('primary card has no coloured left border', (tester) async {
      final primary = _makeSource(id: 'src-1', isPrimary: true);
      final secondary = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerModel: 'Suunto D5',
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [primary, secondary],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Primary status is carried by the chip alone (#3247); the old 3px
      // accent border is gone, so no decorated Container draws one.
      final bordered = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final decoration = w.decoration;
        return decoration is BoxDecoration &&
            decoration.border is Border &&
            (decoration.border! as Border).left.width == 3;
      });
      expect(bordered, findsNothing);
    });

    testWidgets('onSplit callback fires from overflow menu', (tester) async {
      final primary = _makeSource(id: 'src-1', isPrimary: true);
      final secondary = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerModel: 'Suunto D5',
      );

      String? splitId;

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [primary, secondary],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              onSetPrimary: (_) {},
              onSplit: (id) => splitId = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the secondary card's overflow menu (second one)
      final menuButtons = find.byIcon(Icons.more_vert);
      await tester.tap(menuButtons.last);
      await tester.pumpAndSettle();

      // Tap "Split into separate dive"
      await tester.tap(find.text('Split into separate dive'));
      await tester.pumpAndSettle();

      expect(splitId, equals('src-2'));
    });

    testWidgets('three sources show three dividers', (tester) async {
      final src1 = _makeSource(
        id: 'src-1',
        isPrimary: true,
        computerModel: 'Perdix',
      );
      final src2 = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerModel: 'Suunto D5',
      );
      final src3 = _makeSource(
        id: 'src-3',
        isPrimary: false,
        computerModel: 'Garmin Descent',
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [src1, src2, src3],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Two dividers between three cards
      // One below the comparison grid, two between the three cards.
      expect(find.byType(Divider), findsNWidgets(3));
      // One Primary chip; the Secondary chip is gone (#3247).
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Secondary'), findsNothing);
    });
  });

  group('_SourceComparisonGrid', () {
    testWidgets(
      'renders a comparison grid with one column per source when multi-source',
      (tester) async {
        final primary = _makeSource(
          id: 'src-1',
          isPrimary: true,
          computerModel: 'Shearwater Perdix',
          maxDepth: 30.1,
          avgDepth: null,
          duration: 3000,
          waterTemp: 24.0,
          cns: 20.0,
          otu: 15.0,
          decoAlgorithm: 'Buhlmann ZHL-16C',
          gradientFactorLow: 30,
          gradientFactorHigh: 70,
        );
        final secondary = _makeSource(
          id: 'src-2',
          isPrimary: false,
          computerModel: 'Shearwater Teric',
          maxDepth: 30.4,
          avgDepth: null,
          duration: 3060,
          waterTemp: 23.5,
          cns: 22.0,
          otu: null,
          decoAlgorithm: null,
          gradientFactorLow: null,
          gradientFactorHigh: null,
        );

        await tester.pumpWidget(
          testApp(
            child: SingleChildScrollView(
              child: DataSourcesSection(
                dataSources: [primary, secondary],
                diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
                diveId: 'dive-1',
                units: _units,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dataTableFinder = find.byKey(
          DataSourcesSection.comparisonGridKey,
        );
        expect(dataTableFinder, findsOneWidget);

        final table = tester.widget<Table>(dataTableFinder);
        // One "metric" label column + one column per source.
        expect(table.children.first.children, hasLength(3));
        Text headerText(String name) => tester.widget<Text>(
          find.descendant(of: dataTableFinder, matching: find.text(name)),
        );
        expect(headerText('Shearwater Perdix'), isNotNull);
        expect(headerText('Shearwater Teric'), isNotNull);

        // Primary column header is bold; secondary is not.
        expect(
          headerText('Shearwater Perdix').style?.fontWeight,
          equals(FontWeight.bold),
        );
        expect(
          headerText('Shearwater Teric').style?.fontWeight,
          isNot(FontWeight.bold),
        );

        // Row labels use the l10n keys. The source names also appear on the
        // cards below, so lookups stay scoped to the grid.
        expect(
          find.descendant(
            of: dataTableFinder,
            matching: find.text('Max Depth'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dataTableFinder, matching: find.text('Duration')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dataTableFinder,
            matching: find.text('Water Temp'),
          ),
          findsOneWidget,
        );
        expect(find.text('CNS'), findsOneWidget);
        expect(find.text('OTU'), findsOneWidget);
        expect(find.text('Deco Algorithm'), findsOneWidget);
        expect(find.text('GF'), findsOneWidget);
        // avgDepth is null for both sources: row omitted entirely.
        expect(find.text('Avg Depth'), findsNothing);

        // Values formatted via UnitFormatter and scoped to the grid,
        // since equivalent text may also appear on the per-source cards.
        expect(
          find.descendant(of: dataTableFinder, matching: find.text('30.1m')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dataTableFinder, matching: find.text('30.4m')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dataTableFinder, matching: find.text('24°C')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dataTableFinder, matching: find.text('23.5°C')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dataTableFinder, matching: find.text('20%')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dataTableFinder, matching: find.text('50 min')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dataTableFinder, matching: find.text('51 min')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dataTableFinder, matching: find.text('15')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dataTableFinder, matching: find.text('30/70')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dataTableFinder,
            matching: find.text('Buhlmann ZHL-16C'),
          ),
          findsOneWidget,
        );
        // Missing values render as an em dash placeholder.
        expect(
          find.descendant(of: dataTableFinder, matching: find.text('—')),
          findsWidgets,
        );
      },
    );

    testWidgets('column header uses the computer friendly name when set', (
      tester,
    ) async {
      final primary = _makeSource(
        id: 'src-1',
        isPrimary: true,
        computerName: 'My Perdix',
        computerModel: 'Shearwater Perdix AI',
        maxDepth: 30.1,
      );
      final secondary = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerName: null,
        computerModel: 'Shearwater Teric',
        maxDepth: 30.4,
      );

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [primary, secondary],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final grid = find.byKey(DataSourcesSection.comparisonGridKey);
      // Primary column shows the friendly name; secondary (no friendly name)
      // falls back to its model snapshot.
      expect(
        find.descendant(of: grid, matching: find.text('My Perdix')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: grid, matching: find.text('Shearwater Teric')),
        findsOneWidget,
      );
    });

    testWidgets(
      'column header falls back to serial when name and model are absent',
      (tester) async {
        final primary = _makeSource(
          id: 'src-1',
          isPrimary: true,
          computerModel: 'Shearwater Perdix',
          maxDepth: 30.0,
        );
        final secondary = _makeSource(
          id: 'src-2',
          isPrimary: false,
          computerName: null,
          computerModel: null,
          computerSerial: 'SN-ONLY-42',
          maxDepth: 31.0,
        );

        await tester.pumpWidget(
          testApp(
            child: SingleChildScrollView(
              child: DataSourcesSection(
                dataSources: [primary, secondary],
                diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
                diveId: 'dive-1',
                units: _units,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final grid = find.byKey(DataSourcesSection.comparisonGridKey);
        // No friendly name and no model: the serial identifies the column,
        // not the generic "Unknown" label. It shows twice in the grid: the
        // column header, and the Serial row beneath it.
        final serial = find.descendant(
          of: grid,
          matching: find.text('SN-ONLY-42'),
        );
        expect(serial, findsNWidgets(2));
        expect(find.text('Unknown Computer'), findsNothing);
        // The first match is the header, above the first metric row.
        expect(
          tester.getRect(serial.first).bottom,
          lessThanOrEqualTo(
            tester
                .getRect(
                  find.descendant(of: grid, matching: find.text('Max Depth')),
                )
                .top,
          ),
        );
      },
    );

    testWidgets('does not render a comparison grid when single-source', (
      tester,
    ) async {
      final source = _makeSource();

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(DataSourcesSection.comparisonGridKey), findsNothing);
    });
  });

  group('CollapsibleSection behavior', () {
    testWidgets('section is expanded by default', (tester) async {
      final source = _makeSource();

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Content is visible when expanded
      expect(find.text('Shearwater Perdix'), findsOneWidget);
      // The storage icon is the header icon
      expect(find.byIcon(Icons.storage), findsOneWidget);
    });

    testWidgets('can be collapsed by tapping header', (tester) async {
      final source = _makeSource();

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify expanded: content visible
      expect(find.text('Shearwater Perdix'), findsOneWidget);

      // Tap the header to collapse (find the InkWell via text)
      await tester.tap(find.text('Data Source'));
      await tester.pumpAndSettle();

      // After collapsing, AnimatedCrossFade transitions to firstChild
      // (SizedBox.shrink), so the content is still in the tree but hidden.
      // The expand_more icon should still be present (it rotates).
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('can be expanded after collapsing', (tester) async {
      final source = _makeSource();

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [source],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Collapse
      await tester.tap(find.text('Data Source'));
      await tester.pumpAndSettle();

      // Re-expand
      await tester.tap(find.text('Data Source'));
      await tester.pumpAndSettle();

      // Content visible again
      expect(find.text('Shearwater Perdix'), findsOneWidget);
    });
  });

  group('Separate combined dives', () {
    testWidgets('hides Separate when onSeparate is null', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [_makeSource()],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A lone source with nothing to separate has no section menu at all.
      expect(find.byKey(DataSourcesSection.sectionMenuKey), findsNothing);
      expect(find.text('Separate combined dives'), findsNothing);
    });

    testWidgets('offers Separate on a single-card combined dive', (
      tester,
    ) async {
      // The repro of issue #1504: two file imports combined collapse to one
      // display source, so the per-source Split is gone. Separate is a
      // section-level action and does not depend on the source count.
      var separated = 0;

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [_makeSource(computerId: null)],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              onSeparate: () => separated++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DataSourcesSection.sectionMenuKey));
      await tester.pumpAndSettle();
      expect(find.text('Separate combined dives'), findsOneWidget);
      await tester.tap(find.text('Separate combined dives'));
      await tester.pumpAndSettle();

      expect(separated, 1);
    });

    testWidgets('shows Separate alongside Compare in 3D on a multi-source '
        'dive', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [
                _makeSource(),
                _makeSource(
                  id: 'src-2',
                  computerId: 'comp-2',
                  isPrimary: false,
                  computerModel: 'Shearwater Teric',
                ),
              ],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              onSeparate: () {},
              onCompareIn3d: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DataSourcesSection.sectionMenuKey));
      await tester.pumpAndSettle();
      expect(find.text('Compare in 3D'), findsOneWidget);
      expect(find.text('Separate combined dives'), findsOneWidget);
    });
  });
}
