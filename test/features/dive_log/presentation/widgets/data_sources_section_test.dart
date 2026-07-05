import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      'shows "Primary" and "Secondary" badges for multi-source dive',
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
        expect(find.text('Secondary'), findsOneWidget);
      },
    );

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
      },
    );

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
      expect(find.text('Max depth'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Water temp'), findsOneWidget);
      expect(find.text('CNS%'), findsOneWidget);
    });

    testWidgets('shows "--" for missing fields on secondary card', (
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

      // "--" should appear for missing metrics on the secondary card
      expect(find.text('--'), findsWidgets);
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
      expect(find.text('15.0%'), findsOneWidget);
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

    testWidgets('shows entry and exit times in details grid', (tester) async {
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

      expect(find.text('Entry'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget);
      expect(find.text('10:50 AM'), findsOneWidget);
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

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('primary card has colored left border', (tester) async {
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

      // Find Container widgets with BoxDecoration that have a left border.
      // The primary card gets a left border with colorScheme.primary.
      final containers = find.byType(Container);
      var foundBorderedContainer = false;
      for (final container in containers.evaluate()) {
        final widget = container.widget as Container;
        final decoration = widget.decoration;
        if (decoration is BoxDecoration && decoration.border is Border) {
          final border = decoration.border! as Border;
          if (border.left.width == 3) {
            foundBorderedContainer = true;
            break;
          }
        }
      }
      expect(foundBorderedContainer, isTrue);
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

    testWidgets('three sources show two dividers', (tester) async {
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
      expect(find.byType(Divider), findsNWidgets(2));
      // One Primary badge, two Secondary badges
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Secondary'), findsNWidgets(2));
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

        final dataTableFinder = find.byType(DataTable);
        expect(dataTableFinder, findsOneWidget);

        final dataTable = tester.widget<DataTable>(dataTableFinder);
        // One "metric" label column + one column per source.
        expect(dataTable.columns, hasLength(3));
        expect(
          (dataTable.columns[1].label as Text).data,
          equals('Shearwater Perdix'),
        );
        expect(
          (dataTable.columns[2].label as Text).data,
          equals('Shearwater Teric'),
        );

        // Primary column header is bold; secondary is not.
        final primaryHeaderStyle = (dataTable.columns[1].label as Text).style;
        expect(primaryHeaderStyle?.fontWeight, equals(FontWeight.bold));
        final secondaryHeaderStyle = (dataTable.columns[2].label as Text).style;
        expect(secondaryHeaderStyle?.fontWeight, isNot(FontWeight.bold));

        // Row labels use the new l10n keys. "Duration" also appears on each
        // per-source card's own metrics row, so scope that lookup to the grid.
        expect(find.text('Max Depth'), findsOneWidget);
        expect(
          find.descendant(of: dataTableFinder, matching: find.text('Duration')),
          findsOneWidget,
        );
        expect(find.text('Water Temp'), findsOneWidget);
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
          find.descendant(of: dataTableFinder, matching: find.text('24.0°C')),
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

      final dataTable = tester.widget<DataTable>(find.byType(DataTable));
      // Primary column shows the friendly name; secondary (no friendly name)
      // falls back to its model snapshot.
      expect((dataTable.columns[1].label as Text).data, equals('My Perdix'));
      expect(
        (dataTable.columns[2].label as Text).data,
        equals('Shearwater Teric'),
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

        final dataTable = tester.widget<DataTable>(find.byType(DataTable));
        // No friendly name and no model: the serial identifies the column,
        // not the generic "Unknown" label.
        expect((dataTable.columns[2].label as Text).data, equals('SN-ONLY-42'));
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

      expect(find.byType(DataTable), findsNothing);
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
}
