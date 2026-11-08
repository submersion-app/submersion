import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding_subjects.dart';
import 'package:submersion/features/data_quality/domain/repairs/quality_repair_action.dart';
import 'package:submersion/features/data_quality/presentation/widgets/dive_identity_label.dart';
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
  depthRate: _fmt,
  limitDepth: _fmt,
  pressure: _fmt,
  temperature: _fmt,
  temperatureDelta: _fmt,
  sac: _fmt,
  date: _fmtDate,
  dateTime: _fmtDate,
  time: _fmtDate,
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
    DiveIdentityLabel? relatedDive,
    String? computerName,
    List<QualityTankRef> tanks = const [],
    Widget? evidence,
    String? foreignDiveId,
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
            relatedDive: relatedDive,
            computerName: computerName,
            tanks: tanks,
            evidence: evidence,
            foreignDiveId: foreignDiveId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Tap the leading severity icon to toggle expansion. Tapping the ListTile
  // centre is unreliable because the repair button below the detail can cover
  // it.
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
    testWidgets('renders under the detail when a non-goto repair exists', (
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

  group('missing gas switch (#165)', () {
    Map<String, Object?> start(String tankId, int t) => {
      'tankId': tankId,
      'tankPosition': 1,
      't': t,
      'depth': 21.0,
      'o2Percent': 50.0,
      'hePercent': 0.0,
    };

    testWidgets('one switch: the button adds it', (tester) async {
      final repaired = <QualityRepairAction>[];
      await pumpCard(
        tester,
        finding: _finding(
          detectorId: 'missing_gas_switch',
          params: {
            'missingSwitches': [start('deco', 1800)],
            'deepStarts': const [],
          },
        ),
        onRepair: repaired.add,
      );
      expect(find.text('Add gas switch'), findsOneWidget);
      await tester.tap(find.text('Add gas switch'));
      await tester.pumpAndSettle();
      final add = repaired.single as AddGasSwitchesRepair;
      expect(add.switches.single, (tankId: 'deco', t: 1800, depth: 21.0));
    });

    testWidgets('several switches: the button counts them', (tester) async {
      await pumpCard(
        tester,
        finding: _finding(
          detectorId: 'missing_gas_switch',
          params: {
            'missingSwitches': [start('deco', 1800), start('back', 2400)],
            'deepStarts': const [],
          },
        ),
      );
      expect(find.text('Add 2 gas switches'), findsOneWidget);
    });

    testWidgets('only too-deep starts: no button', (tester) async {
      await pumpCard(
        tester,
        finding: _finding(
          detectorId: 'missing_gas_switch',
          params: {
            'missingSwitches': const [],
            'deepStarts': [
              {...start('deco', 600), 'depth': 40.0, 'modMeters': 22.0},
            ],
          },
        ),
      );
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('source placed away from its profile fit (#4296)', () {
    final finding = _finding(
      detectorId: 'clock_offset',
      params: const {'sourceId': 's2', 'profileOffsetSeconds': 1160},
    );

    testWidgets('offers to line the computer up by its profile', (
      tester,
    ) async {
      final repaired = <QualityRepairAction>[];
      await pumpCard(tester, finding: finding, onRepair: repaired.add);

      final primary = find.byType(FilledButton);
      expect(
        find.descendant(
          of: primary,
          matching: find.text('Line up this computer by its profile'),
        ),
        findsOneWidget,
      );
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(repaired.single, isA<SourceProfileShiftRepair>());
    });

    testWidgets('names the computer when one is known', (tester) async {
      await pumpCard(tester, finding: finding, computerName: 'Perdix 2');
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Line up Perdix 2 by its profile'),
        ),
        findsOneWidget,
      );
    });
  });

  group('source clock offset (#3655)', () {
    final finding = _finding(
      detectorId: 'clock_offset',
      params: const {'offsetHours': 1, 'sourceId': 's2'},
    );

    testWidgets('leads with fixing the computer, logbook shift second', (
      tester,
    ) async {
      final repaired = <QualityRepairAction>[];
      await pumpCard(tester, finding: finding, onRepair: repaired.add);

      final primary = find.byType(FilledButton);
      expect(
        find.descendant(
          of: primary,
          matching: find.text("Fix this computer's clock by -1 h"),
        ),
        findsOneWidget,
      );
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(repaired.single, isA<SourceClockShiftRepair>());

      await toggleExpand(tester);
      await tester.tap(find.text('Shift logbook time by +1 h'));
      await tester.pumpAndSettle();
      expect(repaired.last, isA<TimeShiftRepair>());
    });

    // The button says whose clock it corrects, matching the row above it
    // (issue #4209).
    testWidgets('names the computer when one is known', (tester) async {
      await pumpCard(tester, finding: finding, computerName: 'Suunto EON Core');
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text("Fix Suunto EON Core's clock by -1 h"),
        ),
        findsOneWidget,
      );
      expect(find.text('Recorded by Suunto EON Core'), findsOneWidget);
    });
  });

  group('source conflict repairs name the source (#4209)', () {
    final conflict = _finding(
      detectorId: 'source_conflict',
      params: const {
        'sourceId': 's1',
        'primarySeconds': 1390,
        'sourceSeconds': 4018,
      },
    );

    testWidgets('set-primary and split name the source', (tester) async {
      await pumpCard(
        tester,
        finding: conflict,
        computerName: 'Shearwater Perdix 2',
      );
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Make Shearwater Perdix 2 the primary source'),
        ),
        findsOneWidget,
      );
      await toggleExpand(tester);
      expect(
        find.text('Split Shearwater Perdix 2 into its own dive'),
        findsOneWidget,
      );
    });

    testWidgets('fall back to the unnamed labels without a name', (
      tester,
    ) async {
      await pumpCard(tester, finding: conflict);
      expect(find.text('Make this source primary'), findsOneWidget);
      await toggleExpand(tester);
      expect(find.text('Split into separate dives'), findsOneWidget);
    });
  });

  group('tank row (#4209)', () {
    final pressure = _finding(
      detectorId: 'pressure_anomaly',
      params: const {'tankId': 't2', 'startBar': 50.0, 'endBar': 200.0},
    );

    testWidgets('names the tank a finding is about', (tester) async {
      await pumpCard(
        tester,
        finding: pressure,
        tanks: const [QualityTankRef(number: 2)],
      );
      expect(find.text('Affects Tank 2'), findsOneWidget);
      expect(find.byIcon(Icons.propane_tank_outlined), findsOneWidget);
    });

    testWidgets('adds the tank name and lists both tanks of a pair', (
      tester,
    ) async {
      await pumpCard(
        tester,
        finding: _finding(
          detectorId: 'tank_assignment',
          params: const {'tankIdA': 'a', 'tankIdB': 'b'},
        ),
        tanks: const [
          QualityTankRef(number: 1),
          QualityTankRef(number: 3, name: 'Stage'),
        ],
      );
      expect(find.text('Affects Tank 1 and Tank 3 · Stage'), findsOneWidget);
    });

    testWidgets('no tanks, no row', (tester) async {
      await pumpCard(tester, finding: pressure);
      expect(find.byIcon(Icons.propane_tank_outlined), findsNothing);
    });
  });

  group('no-automatic-fix note', () {
    // A card with no repair button used to render as a bare row, which reads
    // as a broken button rather than a deliberate judgment call (issue #1035).
    testWidgets('explains itself when the only option is go-to-dive', (
      tester,
    ) async {
      await pumpCard(
        tester,
        finding: _finding(
          detectorId: 'gas_mod',
          params: const {'o2Percent': 10},
        ),
      );
      expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);
    });

    testWidgets('absent when a repair is offered', (tester) async {
      await pumpCard(tester, finding: _finding());
      expect(find.byIcon(Icons.build_circle_outlined), findsNothing);
    });

    testWidgets('announces the message and nothing for the icon', (
      tester,
    ) async {
      // Icon wraps its glyph in ExcludeSemantics and only contributes a label
      // when semanticLabel is set, so the decorative icon stays silent and the
      // text carries the meaning.
      final handle = tester.ensureSemantics();
      await pumpCard(
        tester,
        finding: _finding(
          detectorId: 'gas_mod',
          params: const {'o2Percent': 10},
        ),
      );

      // The tappable ListTile merges the card into one node, so assert on the
      // merged label rather than looking for a node of the note's own.
      final label = tester.getSemantics(find.byType(QualityFindingCard)).label;
      expect(label, contains('No automatic fix.'));
      expect(label, isNot(contains('build_circle')));
      expect(label, isNot(contains('info_outline')));
      handle.dispose();
    });

    testWidgets('shown for a temperature step that cannot be smoothed', (
      tester,
    ) async {
      await pumpCard(
        tester,
        finding: _finding(
          detectorId: 'temp_anomaly',
          params: const {'deltaC': 9.0, 'spikeShaped': false},
        ),
      );
      expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);
    });
  });

  group('scalar water temperature repair', () {
    testWidgets('a Fahrenheit reading offers a one-tap conversion', (
      tester,
    ) async {
      final repaired = <QualityRepairAction>[];
      await pumpCard(
        tester,
        finding: _finding(
          detectorId: 'temp_anomaly',
          params: const {'waterTempC': 78.0, 'fahrenheitSuspected': true},
        ),
        onRepair: repaired.add,
      );

      expect(find.byIcon(Icons.build_circle_outlined), findsNothing);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      final action = repaired.single as ConvertWaterTempRepair;
      expect(action.diveId, 'd1');
      expect(action.kelvinScale, isFalse);
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
      // Primary rendered as FilledButton.tonal under the detail.
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
    // repair the primary action.
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
            params: const {'deltaC': 5.0, 'spikeShaped': true},
            related: null,
          ),
          'convertTemp': (
            detector: 'temp_anomaly',
            params: const {
              'minTempC': 280.0,
              'maxTempC': 300.0,
              'fahrenheitAsKelvinSuspected': true,
            },
            related: null,
          ),
          'smoothRates': (
            detector: 'impossible_rate',
            params: const {'startSeconds': 60, 'interpolatable': true},
            related: null,
          ),
          'clampNegative': (
            detector: 'depth_spike',
            params: const {'sampleCount': 4, 'minDepth': -3.0},
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
        // Primary label built for the primary button.
        expect(find.byType(FilledButton), findsOneWidget);
        // Expand to build every secondary label too.
        await toggleExpand(tester);
        expect(find.byType(OverflowBar), findsOneWidget);
      });
    });
  });

  // Each removable side of a shared gear finding names its profile, and a
  // side whose name was not recorded still reads as a sentence (#2853).
  testWidgets('shared gear repairs name whose dive loses the item', (
    tester,
  ) async {
    await pumpCard(
      tester,
      finding: _finding(
        detectorId: 'shared_gear_overlap',
        relatedDiveId: 'd2',
        params: const {
          'equipmentId': 'light',
          'itemName': 'Light',
          'partIds': <String>[],
          'dives': {
            'd1': {'diverName': 'Anna', 'entryMs': 0, 'removable': true},
            'd2': {'diverName': '', 'entryMs': 0, 'removable': true},
          },
        },
      ),
    );
    await toggleExpand(tester);
    expect(find.text("Remove from Anna's dive"), findsOneWidget);
    expect(find.text("Remove from another profile's dive"), findsOneWidget);
  });

  // A shared gear pair spans two profiles; each sees it but may act only on
  // its own dive (issue #3049).
  group('a pair with another profile\'s dive', () {
    QualityFinding crossDiver() => _finding(
      detectorId: 'shared_gear_overlap',
      relatedDiveId: 'd2',
      params: const {
        'equipmentId': 'light',
        'itemName': 'Light',
        'partIds': <String>[],
        'dives': {
          'd1': {'diverName': 'Anna', 'entryMs': 0, 'removable': true},
          'd2': {'diverName': 'Ben', 'entryMs': 0, 'removable': true},
        },
      },
    );

    testWidgets('offers no repair on the other profile\'s dive', (
      tester,
    ) async {
      await pumpCard(tester, finding: crossDiver(), foreignDiveId: 'd1');
      await toggleExpand(tester);
      expect(find.text("Remove from Anna's dive"), findsNothing);
      expect(find.text("Remove from Ben's dive"), findsOneWidget);
    });

    testWidgets('names the other profile\'s dive without opening it', (
      tester,
    ) async {
      final tapped = <String>[];
      await pumpCard(
        tester,
        finding: crossDiver(),
        foreignDiveId: 'd1',
        relatedDive: const DiveIdentityLabel(headline: 'Anna #7'),
        onGoToDive: tapped.add,
      );
      await tester.tap(find.text('Paired with Anna #7'));
      await tester.pumpAndSettle();
      expect(tapped, isEmpty);
    });

    testWidgets('goes to the active diver\'s own dive', (tester) async {
      final tapped = <String>[];
      await pumpCard(
        tester,
        finding: crossDiver(),
        foreignDiveId: 'd1',
        onGoToDive: tapped.add,
      );
      await toggleExpand(tester);
      await tester.tap(find.text('Go to dive'));
      await tester.pumpAndSettle();
      expect(tapped, ['d2']);
    });
  });

  group('finding context rows', () {
    // A cross-dive finding's message can only ever say "a dive 1 min apart":
    // the message builder renders numeric params and holds no prose. Naming
    // the second dive is what makes consolidating it a decision rather than a
    // guess.
    testWidgets('names the paired dive and links to it', (tester) async {
      final tapped = <String>[];
      await pumpCard(
        tester,
        finding: _finding(
          detectorId: 'duplicate',
          relatedDiveId: 'd2',
          params: const {'score': 0.5, 'timeDiffMinutes': 1},
        ),
        relatedDive: const DiveIdentityLabel(headline: '#43 · Night dive'),
        onGoToDive: tapped.add,
      );

      expect(find.text('Paired with #43 · Night dive'), findsOneWidget);
      await tester.tap(find.text('Paired with #43 · Night dive'));
      await tester.pumpAndSettle();
      expect(tapped, ['d2']);
    });

    testWidgets('omits the paired row when there is no related dive', (
      tester,
    ) async {
      await pumpCard(tester, finding: _finding());
      expect(find.textContaining('Paired with'), findsNothing);
    });

    testWidgets('names the computer that recorded the flagged data', (
      tester,
    ) async {
      await pumpCard(tester, finding: _finding(), computerName: 'Perdix AI');
      expect(find.text('Recorded by Perdix AI'), findsOneWidget);
    });

    testWidgets('omits the computer row when the finding names none', (
      tester,
    ) async {
      await pumpCard(tester, finding: _finding());
      expect(find.textContaining('Recorded by'), findsNothing);
    });
  });
}
