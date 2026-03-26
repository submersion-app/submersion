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
  String? computerModel = 'Shearwater Perdix',
  String? computerSerial = 'SN-12345',
  String? sourceFormat = 'SSRF',
  String? sourceFileName = 'dive_log.ssrf',
  double? maxDepth = 30.0,
  double? avgDepth = 18.5,
  int? duration = 3000,
  double? waterTemp = 22.0,
  double? cns = 15.0,
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
    computerModel: computerModel,
    computerSerial: computerSerial,
    sourceFormat: sourceFormat,
    sourceFileName: sourceFileName,
    maxDepth: maxDepth,
    avgDepth: avgDepth,
    duration: duration,
    waterTemp: waterTemp,
    cns: cns,
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
                onUnlink: (_) {},
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
        expect(find.text('Unlink'), findsOneWidget);

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
              onUnlink: (_) {},
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
      // "Unlink" should still appear
      expect(find.text('Unlink'), findsOneWidget);
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
              onUnlink: (_) {},
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

      // Tap the secondary card (find by model name)
      await tester.tap(find.text('Suunto D5'));
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

    testWidgets('shows "Unknown Source" when computerModel is null', (
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

      expect(find.text('Unknown Source'), findsOneWidget);
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
              // onSetPrimary and onUnlink are null
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

    testWidgets('onUnlink callback fires from overflow menu', (tester) async {
      final primary = _makeSource(id: 'src-1', isPrimary: true);
      final secondary = _makeSource(
        id: 'src-2',
        isPrimary: false,
        computerModel: 'Suunto D5',
      );

      String? unlinkedId;

      await tester.pumpWidget(
        testApp(
          child: SingleChildScrollView(
            child: DataSourcesSection(
              dataSources: [primary, secondary],
              diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
              diveId: 'dive-1',
              units: _units,
              onSetPrimary: (_) {},
              onUnlink: (id) => unlinkedId = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the secondary card's overflow menu (second one)
      final menuButtons = find.byIcon(Icons.more_vert);
      await tester.tap(menuButtons.last);
      await tester.pumpAndSettle();

      // Tap "Unlink"
      await tester.tap(find.text('Unlink'));
      await tester.pumpAndSettle();

      expect(unlinkedId, equals('src-2'));
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
