import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(Widget child) => testApp(
  overrides: [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())],
  child: SizedBox(width: 500, height: 600, child: child),
);

Future<void> _seedDecoPlan(WidgetTester tester, Finder anchor) async {
  final container = ProviderScope.containerOf(tester.element(anchor));
  container
      .read(divePlanNotifierProvider.notifier)
      .addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
  await tester.pumpAndSettle();
}

/// A hand-built outcome: a descent, a level leg and an ascent straight to
/// the surface with no stops, so the table has lines but no deco.
PlanOutcome _noDecoOutcome({
  int airBreakSeconds = 0,
  List<PlanTankUsage> tankUsages = const [],
}) {
  PlanScheduleRow row(
    PlanScheduleRowKind kind,
    double depth,
    int duration,
    int runtime, {
    int airBreak = 0,
  }) => PlanScheduleRow(
    kind: kind,
    depthMeters: depth,
    durationSeconds: duration,
    runtimeSeconds: runtime,
    gasFO2: 0.32,
    gasFHe: 0,
    airBreakSeconds: airBreak,
  );
  return PlanOutcome(
    runtimeSeconds: 1620,
    maxDepth: 18,
    ndlAtBottom: 600,
    ttsAtBottom: 120,
    stops: const [],
    schedule: [
      row(PlanScheduleRowKind.descent, 18, 240, 240),
      row(PlanScheduleRowKind.level, 18, 1200, 1440, airBreak: airBreakSeconds),
      row(PlanScheduleRowKind.ascent, 0, 180, 1620),
    ],
    segmentOutcomes: const [],
    tankUsages: tankUsages,
    cnsEnd: 5,
    otuTotal: 10,
    issues: const [],
    endTissue: const BuhlmannState(compartments: []),
    tissueTimeline: const [],
    ceilingTrace: const [],
  );
}

Widget _outcomeHarness(PlanOutcome outcome) => testApp(
  overrides: [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    activePlanOutcomeProvider.overrideWithValue(outcome),
  ],
  child: SizedBox(
    width: 500,
    height: 600,
    child: PlanResultsSheet(controller: ScrollController()),
  ),
);

void main() {
  testWidgets('gas row shows used and end liters/pressure readings', (
    tester,
  ) async {
    await tester.pumpWidget(
      _outcomeHarness(
        _noDecoOutcome(
          tankUsages: const [
            PlanTankUsage(
              tankId: 'back',
              litersUsed: 411,
              totalLiters: 2000,
              startPressure: 200,
              remainingPressure: 163,
              percentUsed: 18.5,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('used: 411L/37bar'), findsOneWidget);
    expect(find.text('end: 1589L/163bar'), findsOneWidget);
    final usedFinder = find.text('used: 411L/37bar');
    final theme = Theme.of(tester.element(usedFinder));
    expect(
      tester.widget<Text>(usedFinder).style?.fontSize,
      theme.textTheme.labelSmall?.fontSize,
    );
  });

  testWidgets(
    'gas row shows a negative end reading and a two-colour bar when usage '
    'exceeds the cylinder\'s own capacity (#3190)',
    (tester) async {
      await tester.pumpWidget(
        _outcomeHarness(
          _noDecoOutcome(
            tankUsages: const [
              PlanTankUsage(
                tankId: 'back',
                litersUsed: 2500,
                totalLiters: 2000,
                startPressure: 200,
                remainingPressure: -50,
                percentUsed: 125,
                reserveViolation: true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('end: -500L/-50bar'), findsOneWidget);
      // Two colour segments (covered share + shortfall), not the ordinary
      // single-colour LinearProgressIndicator. Scoped to opaque boxes: the
      // initial route's own page-transition scrim is a transparent
      // ColoredBox that `find.byType` would otherwise also pick up.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final barBoxes = find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color.a > 0,
      );
      expect(barBoxes, findsNWidgets(2));
      // Both segments must actually occupy the bar's 4 px height: a Row
      // hands childless ColoredBoxes loose cross-axis constraints, under
      // which they collapse to 0 px tall and render nothing.
      final segmentSizes = tester
          .widgetList<ColoredBox>(barBoxes)
          .map((w) => tester.getSize(find.byWidget(w)))
          .toList();
      for (final size in segmentSizes) {
        expect(size.height, 4.0);
        expect(size.width, greaterThan(0.0));
      }
      // 2000 of 2500 L covered: the blue share is four times the red one.
      expect(segmentSizes[0].width / segmentSizes[1].width, closeTo(4.0, 0.05));
    },
  );

  testWidgets('runtime table says no deco above the rows when there are '
      'lines but no stops', (tester) async {
    await tester.pumpWidget(_outcomeHarness(_noDecoOutcome()));
    await tester.pumpAndSettle();

    expect(find.text('No decompression required'), findsOneWidget);
    // The table still prints: header plus the three authored lines.
    expect(find.text('Depth'), findsOneWidget);
    expect(find.text('↘'), findsOneWidget);
    expect(find.text('→'), findsOneWidget);
    expect(find.text('↗'), findsOneWidget);
    expect(find.text('−'), findsNothing);
    // Whole minutes: 4, 20 and 3 add up to the 27-minute runtime. The first
    // line's duration and runtime are the same number, so it prints twice.
    expect(find.text('4′'), findsNWidgets(2));
    expect(find.text('20′'), findsOneWidget);
    expect(find.text('24′'), findsOneWidget);
    expect(find.text('3′'), findsOneWidget);
    expect(find.text('27′'), findsOneWidget);
    expect(find.textContaining('(+'), findsNothing);
  });

  testWidgets(
    'the gas column repeats the active gas on every line, not just the '
    'switch',
    (tester) async {
      const outcome = PlanOutcome(
        runtimeSeconds: 420,
        maxDepth: 18,
        ndlAtBottom: 600,
        ttsAtBottom: 120,
        stops: [],
        schedule: [
          PlanScheduleRow(
            kind: PlanScheduleRowKind.descent,
            depthMeters: 18,
            durationSeconds: 240,
            runtimeSeconds: 240,
            gasFO2: 0.32,
            gasFHe: 0,
            gasSwitch: true,
          ),
          PlanScheduleRow(
            kind: PlanScheduleRowKind.level,
            depthMeters: 18,
            durationSeconds: 180,
            runtimeSeconds: 420,
            gasFO2: 0.32,
            gasFHe: 0,
            gasSwitch: false,
          ),
        ],
        segmentOutcomes: [],
        tankUsages: [],
        cnsEnd: 5,
        otuTotal: 10,
        issues: [],
        endTissue: BuhlmannState(compartments: []),
        tissueTimeline: [],
        ceilingTrace: [],
      );
      await tester.pumpWidget(_outcomeHarness(outcome));
      await tester.pumpAndSettle();

      expect(find.text('EAN32'), findsNWidgets(2));
    },
  );

  testWidgets('the table shows a PO2 and an END column', (tester) async {
    const outcome = PlanOutcome(
      runtimeSeconds: 240,
      maxDepth: 18,
      ndlAtBottom: 600,
      ttsAtBottom: 120,
      stops: [],
      schedule: [
        PlanScheduleRow(
          kind: PlanScheduleRowKind.descent,
          depthMeters: 18,
          durationSeconds: 240,
          runtimeSeconds: 240,
          gasFO2: 0.32,
          gasFHe: 0,
          gasSwitch: true,
          ppO2: 1.26,
          endMeters: 12,
        ),
      ],
      segmentOutcomes: [],
      tankUsages: [],
      cnsEnd: 5,
      otuTotal: 10,
      issues: [],
      endTissue: BuhlmannState(compartments: []),
      tissueTimeline: [],
      ceilingTrace: [],
    );
    await tester.pumpWidget(_outcomeHarness(outcome));
    await tester.pumpAndSettle();

    expect(find.text('PO2'), findsOneWidget);
    expect(find.text('END'), findsOneWidget);
    expect(find.text('1.26'), findsOneWidget);
    expect(find.text('12m'), findsOneWidget);
  });

  testWidgets('a line with an air break shows the break minutes after its '
      'duration', (tester) async {
    await tester.pumpWidget(
      _outcomeHarness(_noDecoOutcome(airBreakSeconds: 290)),
    );
    await tester.pumpAndSettle();

    // 290 s rounds up to a whole 5-minute break.
    expect(find.text("20′ (+5′)"), findsOneWidget);
    expect(find.textContaining('(+'), findsOneWidget);
  });

  testWidgets('PlanStatusChips shows a TTS chip and a tappable issues chip', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(PlanStatusChips(onIssuesTap: () {})));
    await _seedDecoPlan(tester, find.byType(PlanStatusChips));

    expect(find.text('TTS'), findsOneWidget);
    expect(find.textContaining('issue'), findsOneWidget);
  });

  testWidgets('PlanResultsSheet renders runtime table, gas, and issues', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(PlanResultsSheet(controller: ScrollController())),
    );
    await _seedDecoPlan(tester, find.byType(PlanResultsSheet));

    // Runtime table header(s) — the contingency mini-tables repeat it.
    expect(find.text('Depth'), findsWidgets);
    expect(find.text('Duration'), findsWidgets);
    // The table reads like a slate: the authored descent and bottom, then
    // a travel leg to the first stop and a line per computed stop, marked
    // by direction (later stops fold their travel time in, #3138).
    expect(find.text('↘'), findsOneWidget);
    expect(find.text('→'), findsOneWidget);
    expect(find.text('↗'), findsWidgets);
    expect(find.text('−'), findsWidgets);
    // Gas section rendered a per-tank consumption row. A 45 m/25-minute
    // bottom time on a single AL80 of air runs up a deco obligation that
    // exceeds the cylinder's own capacity, so this renders the over-budget
    // two-colour bar (#3190) rather than the ordinary LinearProgressIndicator
    // -- "used:" covers both.
    expect(find.textContaining('used:'), findsWidgets);
    // Air at 45 m trips the critical gas-density issue (issues sit below
    // the contingency tables — scroll the unique section header into the
    // lazy viewport, then nudge so the issue rows build).
    await tester.scrollUntilVisible(
      find.text('WARNINGS'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.textContaining('g/L'), findsWidgets);
  });

  testWidgets(
    'PlanResultsSheet disables its own scrolling and keeps the shared '
    'controller when shrinkWrap is set',
    (tester) async {
      final controller = ScrollController();
      await tester.pumpWidget(
        _harness(PlanResultsSheet(controller: controller, shrinkWrap: true)),
      );
      await _seedDecoPlan(tester, find.byType(PlanResultsSheet));

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.shrinkWrap, isTrue);
      expect(listView.physics, isA<NeverScrollableScrollPhysics>());
      expect(listView.controller, same(controller));
    },
  );

  testWidgets('ContingencyPreviewChip renders nothing without a selection', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(PlanStatusChips(onIssuesTap: () {})));
    await _seedDecoPlan(tester, find.byType(PlanStatusChips));

    expect(find.byType(ContingencyPreviewChip), findsOneWidget);
    expect(find.textContaining('Previewing'), findsNothing);
  });

  testWidgets('ContingencyPreviewChip previews a deviation and clears on tap', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(PlanStatusChips(onIssuesTap: () {})));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanStatusChips)),
    );
    await _seedDecoPlan(tester, find.byType(PlanStatusChips));

    container.read(selectedDeviationProvider.notifier).state = 'deeper';
    await tester.pumpAndSettle();
    expect(find.textContaining('Previewing: +5m'), findsOneWidget);

    container.read(selectedDeviationProvider.notifier).state = 'longer';
    await tester.pumpAndSettle();
    expect(find.textContaining("Previewing: +5′"), findsOneWidget);

    container.read(selectedDeviationProvider.notifier).state = 'both';
    await tester.pumpAndSettle();
    expect(find.textContaining("Previewing: +5m +5′"), findsOneWidget);

    await tester.tap(find.byType(ContingencyPreviewChip));
    await tester.pumpAndSettle();

    expect(container.read(selectedDeviationProvider), isNull);
    expect(find.textContaining('Previewing'), findsNothing);
  });

  testWidgets('ContingencyPreviewChip previews a lost-gas tank and clears both '
      'selections on tap', (tester) async {
    await tester.pumpWidget(_harness(PlanStatusChips(onIssuesTap: () {})));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanStatusChips)),
    );
    await _seedDecoPlan(tester, find.byType(PlanStatusChips));
    container
        .read(divePlanNotifierProvider.notifier)
        .addTank(
          const DiveTank(
            id: 'deco',
            volume: 11.1,
            startPressure: 200,
            gasMix: GasMix(o2: 50),
            role: TankRole.deco,
          ),
        );
    await tester.pumpAndSettle();

    container.read(selectedLostGasTankIdProvider.notifier).state = 'deco';
    await tester.pumpAndSettle();

    expect(find.textContaining('Previewing: Lost EAN50'), findsOneWidget);

    await tester.tap(find.byType(ContingencyPreviewChip));
    await tester.pumpAndSettle();

    expect(container.read(selectedLostGasTankIdProvider), isNull);
    expect(container.read(selectedDeviationProvider), isNull);
    expect(find.textContaining('Previewing'), findsNothing);
  });

  testWidgets('ContingencyPreviewChip hides when the selected tank is gone', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(PlanStatusChips(onIssuesTap: () {})));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanStatusChips)),
    );
    await _seedDecoPlan(tester, find.byType(PlanStatusChips));

    // A selection whose tank the plan never carried stands in for one that
    // went stale (tank removed, role changed, travel-gas flag cleared): the
    // id lingers but no contingency is computed, so the headline stats fall
    // back to the live plan. The chip must not claim a preview that is not
    // in effect.
    container.read(selectedLostGasTankIdProvider.notifier).state = 'removed';
    await tester.pumpAndSettle();

    expect(container.read(selectedContingencyProvider), isNull);
    expect(find.textContaining('Previewing'), findsNothing);
    expect(
      container.read(activePlanOutcomeProvider),
      same(container.read(planOutcomeProvider)),
    );
  });

  group('planIssueMessage for an END warning (issue #1499)', () {
    const issue = PlanIssue(
      type: PlanIssueType.endExceeded,
      severity: PlanIssueSeverity.warning,
      message: 'END 32 m exceeds 30 m',
      atDepth: 32,
      value: 32,
      threshold: 30,
    );

    Future<String> render(
      WidgetTester tester,
      AppSettings settings, {
      PlanIssue issue = issue,
    }) async {
      late String message;
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: Builder(
            builder: (context) {
              message = planIssueMessage(
                context,
                issue,
                UnitFormatter(settings),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return message;
    }

    testWidgets('names both the END and the limit it exceeds', (tester) async {
      expect(
        await render(tester, const AppSettings()),
        'END of 32m exceeds the 30m limit',
      );
    });

    testWidgets('converts both depths to the diver\'s units', (tester) async {
      expect(
        await render(tester, const AppSettings(depthUnit: DepthUnit.feet)),
        'END of 105ft exceeds the 98ft limit',
      );
    });

    testWidgets('never reads as equal to the limit it exceeds', (tester) async {
      // Trimix 21/10 at 34.5 m, O2 narcotic: END 30.05 m against 30 m.
      // Rounding both to whole metres would print "30m exceeds the 30m".
      const barelyOver = PlanIssue(
        type: PlanIssueType.endExceeded,
        severity: PlanIssueSeverity.warning,
        message: 'END 30 m exceeds 30 m',
        atDepth: 34.5,
        value: 30.05,
        threshold: 30,
      );
      expect(
        await render(tester, const AppSettings(), issue: barelyOver),
        'END of 31m exceeds the 30m limit',
      );
    });

    testWidgets('stays above the limit when the END is a hair over it', (
      tester,
    ) async {
      // Inside the float-noise epsilon: END and limit would both show 30.
      const hairOver = PlanIssue(
        type: PlanIssueType.endExceeded,
        severity: PlanIssueSeverity.warning,
        message: 'END 30 m exceeds 30 m',
        value: 30.0000005,
        threshold: 30,
      );
      expect(
        await render(tester, const AppSettings(), issue: hairOver),
        'END of 31m exceeds the 30m limit',
      );
    });
  });

  group('planIssueMessage for a ceiling violation (issue #3354)', () {
    const issue = PlanIssue(
      type: PlanIssueType.ceilingViolated,
      severity: PlanIssueSeverity.critical,
      message: 'Ascent to 0 m passes the 18.4 m deco ceiling',
      atDepth: 0,
      segmentId: 'ascent',
      value: 18.4,
      threshold: 0,
    );

    Future<String> render(WidgetTester tester, AppSettings settings) async {
      late String message;
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: Builder(
            builder: (context) {
              message = planIssueMessage(
                context,
                issue,
                UnitFormatter(settings),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return message;
    }

    testWidgets('names the ceiling the ascent went above', (tester) async {
      expect(
        await render(tester, const AppSettings()),
        'The profile goes above the 18.4m decompression ceiling, '
        'skipping required stops',
      );
    });

    testWidgets('shows the ceiling in the diver\'s units', (tester) async {
      expect(
        await render(tester, const AppSettings(depthUnit: DepthUnit.feet)),
        'The profile goes above the 60.4ft decompression ceiling, '
        'skipping required stops',
      );
    });
  });

  group('planIssueMessage for no usable gas (issue #3741)', () {
    const issue = PlanIssue(
      type: PlanIssueType.noUsableGas,
      severity: PlanIssueSeverity.alert,
      message: 'Rock-bottom minimum of 120 bar leaves no usable gas',
      segmentId: 'tank-1',
      value: 120,
      threshold: 100,
    );

    Future<String> render(WidgetTester tester, AppSettings settings) async {
      late String message;
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: Builder(
            builder: (context) {
              message = planIssueMessage(
                context,
                issue,
                UnitFormatter(settings),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return message;
    }

    testWidgets('names the minimum gas and the fill in order', (tester) async {
      expect(
        await render(tester, const AppSettings()),
        'Rock-bottom minimum of 120 bar leaves no usable gas in a '
        '100 bar fill',
      );
    });

    testWidgets('shows both pressures in the diver\'s units', (tester) async {
      expect(
        await render(tester, const AppSettings(pressureUnit: PressureUnit.psi)),
        'Rock-bottom minimum of 1740 psi leaves no usable gas in a '
        '1450 psi fill',
      );
    });
  });
}
