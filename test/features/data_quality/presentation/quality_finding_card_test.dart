import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/repairs/quality_repair_action.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_card.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_message.dart';

import '../../../helpers/l10n_test_helpers.dart';

QualityFinding _finding({
  String detectorId = 'sample_gap',
  QualitySeverity severity = QualitySeverity.info,
  String? relatedDiveId,
  Map<String, Object?> params = const {'gapCount': 2, 'longestGapSeconds': 90},
}) => QualityFinding(
  id: 'f-$detectorId',
  diveId: 'd1',
  relatedDiveId: relatedDiveId,
  detectorId: detectorId,
  detectorVersion: 1,
  category: QualityCategory.profile,
  severity: severity,
  status: QualityStatus.open,
  params: params,
  createdAt: DateTime.utc(2026, 7, 17),
  updatedAt: DateTime.utc(2026, 7, 17),
);

const _formatters = QualityUnitFormatters(
  depth: _fmt,
  pressure: _fmt,
  temperature: _fmt,
  sac: _fmt,
  date: _fmtDate,
);

String _fmt(double v) => '$v';

String _fmtDate(DateTime d) => '$d';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required QualityFinding finding,
    void Function(QualityRepairAction)? onRepair,
    VoidCallback? onDismiss,
    void Function(String)? onGoToDive,
    Widget? evidence,
  }) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: QualityFindingCard(
            finding: finding,
            formatters: _formatters,
            onRepair: onRepair ?? (_) {},
            onDismiss: onDismiss ?? () {},
            onGoToDive: onGoToDive ?? (_) {},
            evidence: evidence,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Tap the leading severity icon to toggle expansion. Tapping the ListTile
  // centre is unreliable because a wide trailing repair button can cover it.
  Future<void> toggleExpand(WidgetTester tester) async {
    await tester.tap(find.byType(Icon).first);
    await tester.pumpAndSettle();
  }

  group('severity icon and color', () {
    testWidgets('info -> info_outline / primary', (tester) async {
      await pumpCard(tester, finding: _finding(severity: QualitySeverity.info));
      final icon = tester.widget<Icon>(find.byType(Icon).first);
      expect(icon.icon, Icons.info_outline);
      final scheme = Theme.of(
        tester.element(find.byType(Icon).first),
      ).colorScheme;
      expect(icon.color, scheme.primary);
    });

    testWidgets('warning -> warning_amber_outlined / tertiary', (tester) async {
      await pumpCard(
        tester,
        finding: _finding(severity: QualitySeverity.warning),
      );
      final icon = tester.widget<Icon>(find.byType(Icon).first);
      expect(icon.icon, Icons.warning_amber_outlined);
      final scheme = Theme.of(
        tester.element(find.byType(Icon).first),
      ).colorScheme;
      expect(icon.color, scheme.tertiary);
    });

    testWidgets('critical -> error_outline / error', (tester) async {
      await pumpCard(
        tester,
        finding: _finding(severity: QualitySeverity.critical),
      );
      final icon = tester.widget<Icon>(find.byType(Icon).first);
      expect(icon.icon, Icons.error_outline);
      final scheme = Theme.of(
        tester.element(find.byType(Icon).first),
      ).colorScheme;
      expect(icon.color, scheme.error);
    });
  });

  group('expand / collapse', () {
    testWidgets('collapsed hides the overflow bar and clamps subtitle', (
      tester,
    ) async {
      await pumpCard(tester, finding: _finding());
      expect(find.byType(OverflowBar), findsNothing);
      final subtitle = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(ListTile),
              matching: find.byType(Text),
            ),
          )
          .firstWhere((t) => t.overflow == TextOverflow.ellipsis);
      expect(subtitle.maxLines, 1);
    });

    testWidgets('tapping the tile expands and reveals the overflow bar', (
      tester,
    ) async {
      await pumpCard(tester, finding: _finding());
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.byType(OverflowBar), findsOneWidget);
      final subtitle = tester.widget<Text>(
        find
            .descendant(of: find.byType(ListTile), matching: find.byType(Text))
            .last,
      );
      expect(subtitle.maxLines, isNull);
    });

    testWidgets('tapping again collapses', (tester) async {
      await pumpCard(tester, finding: _finding());
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.byType(OverflowBar), findsOneWidget);
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.byType(OverflowBar), findsNothing);
    });

    testWidgets('evidence renders only when expanded and provided', (
      tester,
    ) async {
      const evidenceKey = Key('evidence');
      await pumpCard(
        tester,
        finding: _finding(),
        evidence: const SizedBox(key: evidenceKey),
      );
      expect(find.byKey(evidenceKey), findsNothing);
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.byKey(evidenceKey), findsOneWidget);
    });

    testWidgets('expanded with null evidence still shows the overflow bar', (
      tester,
    ) async {
      await pumpCard(tester, finding: _finding());
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.byType(OverflowBar), findsOneWidget);
    });
  });

  group('primary repair button', () {
    testWidgets('renders in trailing when a non-goto repair exists', (
      tester,
    ) async {
      final repaired = <QualityRepairAction>[];
      await pumpCard(tester, finding: _finding(), onRepair: repaired.add);
      expect(find.byType(FilledButton), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(repaired.single, isA<FillGapsRepair>());
    });

    testWidgets('absent when the only repair option is go-to-dive', (
      tester,
    ) async {
      // gas_mod -> [GoToDiveRepair] which the card filters out.
      await pumpCard(
        tester,
        finding: _finding(
          detectorId: 'gas_mod',
          params: const {'o2Percent': 10},
        ),
      );
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('footer actions when expanded', () {
    testWidgets('go-to-dive button invokes callback with dive id', (
      tester,
    ) async {
      String? goneTo;
      await pumpCard(
        tester,
        finding: _finding(
          detectorId: 'gas_mod',
          params: const {'o2Percent': 10},
        ),
        onGoToDive: (id) => goneTo = id,
      );
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      // With no primary/secondary repairs, footer holds go-to-dive + dismiss.
      final buttons = tester.widgetList<TextButton>(find.byType(TextButton));
      expect(buttons.length, 2);
      await tester.tap(find.byType(TextButton).first);
      await tester.pumpAndSettle();
      expect(goneTo, 'd1');
    });

    testWidgets('dismiss button invokes callback', (tester) async {
      var dismissed = false;
      await pumpCard(
        tester,
        finding: _finding(
          detectorId: 'gas_mod',
          params: const {'o2Percent': 10},
        ),
        onDismiss: () => dismissed = true,
      );
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextButton).last);
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });

    testWidgets('secondary repair buttons render and fire', (tester) async {
      final repaired = <QualityRepairAction>[];
      // source_conflict with sourceId -> SetPrimary(primary), Split, Compare
      await pumpCard(
        tester,
        finding: _finding(
          detectorId: 'source_conflict',
          params: const {'sourceId': 's1', 'primarySeconds': 100},
        ),
        onRepair: repaired.add,
      );
      // Primary rendered as FilledButton.tonal in trailing.
      expect(find.byType(FilledButton), findsOneWidget);
      await toggleExpand(tester);
      // Secondary repairs (Split, Compare) + go-to-dive + dismiss = 4 TextButtons
      final textButtons = tester.widgetList<TextButton>(
        find.byType(TextButton),
      );
      expect(textButtons.length, 4);
      // Tap the first secondary repair (SplitSourceRepair).
      await tester.tap(find.byType(TextButton).first);
      await tester.pumpAndSettle();
      expect(repaired.single, isA<SplitSourceRepair>());
    });
  });

  group('repair label coverage', () {
    // Each entry exercises a distinct repair-label switch arm by making that
    // repair the primary (trailing) action.
    final cases =
        <
          String,
          ({String detector, Map<String, Object?> params, String? related})
        >{
          'shiftTime (offset)': (
            detector: 'clock_offset',
            params: const {'offsetHours': 3},
            related: null,
          ),
          'shiftTime (zero)': (
            detector: 'clock_offset',
            params: const {'entryTimeMs': 0},
            related: null,
          ),
          'consolidate': (
            detector: 'duplicate',
            params: const {'score': 0.9, 'timeDiffMinutes': 5},
            related: 'd2',
          ),
          'combine': (
            detector: 'split_pair',
            params: const {'gapSeconds': 120},
            related: 'd2',
          ),
          'fillGaps': (
            detector: 'sample_gap',
            params: const {'gapCount': 2, 'longestGapSeconds': 90},
            related: null,
          ),
          'despike': (
            detector: 'depth_spike',
            params: const {'depth': 40.0, 'atSeconds': 65},
            related: null,
          ),
          'recompute': (
            detector: 'depth_spike',
            params: const {'storedMaxDepth': 30.0, 'profileMaxDepth': 40.0},
            related: null,
          ),
          'smoothTemp': (
            detector: 'temp_anomaly',
            params: const {'deltaC': 5.0},
            related: null,
          ),
          'convertTemp': (
            detector: 'temp_anomaly',
            params: const {'minTempC': 10.0, 'maxTempC': 300.0},
            related: null,
          ),
          'swapPressures': (
            detector: 'pressure_anomaly',
            params: const {'tankId': 't1', 'startBar': 50.0, 'endBar': 200.0},
            related: null,
          ),
          'setFromSeries': (
            detector: 'pressure_anomaly',
            params: const {
              'tankId': 't1',
              'recordBar': 50.0,
              'seriesBar': 200.0,
              'endpoint': 'start',
            },
            related: null,
          ),
          'swapSeries + reassign': (
            detector: 'tank_assignment',
            params: const {'tankIdA': 'a', 'tankIdB': 'b'},
            related: null,
          ),
          'setPrimary + split + compare': (
            detector: 'source_conflict',
            params: const {'sourceId': 's1', 'primarySeconds': 10},
            related: null,
          ),
        };

    cases.forEach((name, c) {
      testWidgets('renders labels for $name', (tester) async {
        await pumpCard(
          tester,
          finding: _finding(
            detectorId: c.detector,
            params: c.params,
            relatedDiveId: c.related,
          ),
        );
        // Primary label built for trailing button.
        expect(find.byType(FilledButton), findsOneWidget);
        // Expand to build every secondary label too.
        await toggleExpand(tester);
        expect(find.byType(OverflowBar), findsOneWidget);
      });
    });
  });
}
