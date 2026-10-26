import 'package:submersion/features/planner/presentation/chart/plan_chart_backdrop_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_series_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_settings_section.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
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

List<dynamic> _overrides() => [
  settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
];

void main() {
  testWidgets('selecting a deviation ghosts a second profile line', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: _overrides(),
        child: const SizedBox(
          width: 500,
          height: 400,
          child: Column(
            children: [
              Expanded(child: PlanProfileChart()),
              ContingencyChips(),
            ],
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanProfileChart)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();

    PlanChartSeriesPainter seriesPainter() =>
        tester
                .widget<CustomPaint>(find.byKey(const Key('planChartSeries')))
                .painter
            as PlanChartSeriesPainter;
    PlanChartBackdropPainter backdropPainter() =>
        tester
                .widget<CustomPaint>(find.byKey(const Key('planChartBackdrop')))
                .painter
            as PlanChartBackdropPainter;
    expect(seriesPainter().ghost, isNull);

    final baseCeiling = backdropPainter().ceiling;

    await tester.tap(find.text('+5m'));
    await tester.pumpAndSettle();

    expect(container.read(selectedDeviationProvider), 'deeper');
    expect(seriesPainter().ghost, isNotNull);
    // The backdrop's ceiling band must track the previewed contingency, not
    // stay pinned to the base plan.
    expect(backdropPainter().ceiling, seriesPainter().ghost!.ceiling);
    expect(backdropPainter().ceiling, isNot(baseCeiling));

    // Back to base clears the ghost and restores the base ceiling.
    await tester.tap(find.text('Base'));
    await tester.pumpAndSettle();
    expect(seriesPainter().ghost, isNull);
    expect(backdropPainter().ceiling, baseCeiling);
  });

  testWidgets('overlay chips render a single row strip and drive selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: _overrides(),
        child: const Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 8,
                right: 56,
                bottom: 8,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ContingencyChips(overlay: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContingencyChips)),
    );
    // No segments: the selector renders nothing.
    expect(find.text('Base'), findsNothing);

    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();

    expect(find.text('Base'), findsOneWidget);
    // Overlay mode is a single-row strip, not the wrapping layout.
    expect(find.byType(Wrap), findsNothing);

    await tester.tap(find.text('+5m'));
    await tester.pumpAndSettle();
    expect(container.read(selectedDeviationProvider), 'deeper');
  });

  group('the gas row explains a missing turn or min gas (#3603)', () {
    Future<DivePlanNotifier> pumpSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: _overrides(),
          child: SizedBox(
            width: 520,
            height: 900,
            child: PlanResultsSheet(controller: ScrollController()),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanResultsSheet)),
      );
      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
      return notifier;
    }

    testWidgets('no turn rule is named next to the min gas', (tester) async {
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('turn @'), findsNothing);
      expect(find.textContaining('no turn rule set'), findsOneWidget);
      expect(find.textContaining('min gas '), findsOneWidget);
    });

    testWidgets('a back gas without a start pressure says so', (tester) async {
      final notifier = await pumpSheet(tester);
      notifier.updateContingencies(turnRule: domain.TurnPressureRule.thirds);
      final tank = notifier.state.tanks.single;
      notifier.updateTank(
        tank.id,
        DiveTank(
          id: tank.id,
          name: tank.name,
          volume: tank.volume,
          workingPressure: tank.workingPressure,
          gasMix: tank.gasMix,
          role: tank.role,
          order: tank.order,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('turn and min gas need a start pressure'),
        findsOneWidget,
      );
      expect(find.textContaining('turn @'), findsNothing);
    });

    testWidgets('with no depth yet, only the turn names the start pressure', (
      tester,
    ) async {
      // Min gas needs a depth to work from, so before any segment exists the
      // turn is the one figure a missing start pressure blanks.
      await tester.pumpWidget(
        testApp(
          overrides: _overrides(),
          child: SizedBox(
            width: 520,
            height: 900,
            child: PlanResultsSheet(controller: ScrollController()),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanResultsSheet)),
      );
      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.updateContingencies(turnRule: domain.TurnPressureRule.thirds);
      final tank = notifier.state.tanks.single;
      notifier.updateTank(
        tank.id,
        DiveTank(
          id: tank.id,
          name: tank.name,
          volume: tank.volume,
          workingPressure: tank.workingPressure,
          gasMix: tank.gasMix,
          role: tank.role,
          order: tank.order,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('turn needs a start pressure'),
        findsOneWidget,
      );
      expect(find.textContaining('min gas'), findsNothing);
    });

    testWidgets('no rule and no start pressure name each input', (
      tester,
    ) async {
      final notifier = await pumpSheet(tester);
      final tank = notifier.state.tanks.single;
      notifier.updateTank(
        tank.id,
        DiveTank(
          id: tank.id,
          name: tank.name,
          volume: tank.volume,
          workingPressure: tank.workingPressure,
          gasMix: tank.gasMix,
          role: tank.role,
          order: tank.order,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('no turn rule set'), findsOneWidget);
      expect(
        find.textContaining('min gas needs a start pressure'),
        findsOneWidget,
      );
    });

    testWidgets('a zero-litre back gas names the missing size', (tester) async {
      final notifier = await pumpSheet(tester);
      final tank = notifier.state.tanks.single;
      notifier.updateTank(tank.id, tank.copyWith(volume: 0));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('min gas needs a cylinder size'),
        findsOneWidget,
      );
    });
  });

  testWidgets('sheet lists deviation tables and turn pressure', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: _overrides(),
        child: SizedBox(
          width: 520,
          height: 900,
          child: PlanResultsSheet(controller: ScrollController()),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanResultsSheet)),
    );
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    notifier.updateContingencies(turnRule: domain.TurnPressureRule.thirds);
    await tester.pumpAndSettle();

    expect(find.textContaining('turn @'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('CONTINGENCIES'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('CONTINGENCIES'), findsOneWidget);

    // The deviation tables are collapsed by default (they cost extra engine
    // runs); expand the section before the sub-tables render. Assert on the
    // depth-deviation label '+5m', which is unique to the contingency section
    // (the always-visible range table uses +3m/+6m columns).
    expect(find.text('+5m'), findsNothing);
    expect(container.read(contingenciesExpandedProvider), isFalse);
    await tester.tap(find.text('CONTINGENCIES'));
    await tester.pumpAndSettle();
    expect(container.read(contingenciesExpandedProvider), isTrue);

    await tester.scrollUntilVisible(
      find.text('+5m'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('+5m'), findsOneWidget);
  });

  testWidgets(
    'tapping a deviation row in the sheet selects it and collapsing hides '
    'its table',
    (tester) async {
      // Tall physical surface so the whole sheet fits without scrolling --
      // see the "marking a tank lost" test below for why.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(520, 3000);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        testApp(
          overrides: _overrides(),
          child: SizedBox(
            width: 520,
            height: 3000,
            child: PlanResultsSheet(controller: ScrollController()),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanResultsSheet)),
      );
      container
          .read(divePlanNotifierProvider.notifier)
          .addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONTINGENCIES'));
      await tester.pumpAndSettle();

      // Selecting the row's own chip (not the separate ContingencyChips
      // widget, which isn't in this tree) drives the same provider.
      await tester.tap(find.text('+5m'));
      await tester.pumpAndSettle();
      expect(container.read(selectedDeviationProvider), 'deeper');
      expect(container.read(selectedLostGasTankIdProvider), isNull);

      // Tapping again deselects.
      await tester.tap(find.text('+5m'));
      await tester.pumpAndSettle();
      expect(container.read(selectedDeviationProvider), isNull);

      // Collapsing hides the row's runtime table but keeps its chip.
      await tester.tap(find.byIcon(Icons.expand_more).first);
      await tester.pumpAndSettle();
      expect(
        container.read(collapsedContingencyKeysProvider),
        contains('deeper'),
      );
      expect(find.text('+5m'), findsOneWidget);
    },
  );

  testWidgets(
    'marking a tank lost ghosts a profile line and clears the deviation '
    'selection',
    (tester) async {
      // A tall physical surface (not just a tall SizedBox, which a Scaffold
      // body would just clamp back down) so the whole results sheet fits
      // without scrolling -- the section's content height changes as
      // contingencies are selected/collapsed, which would otherwise make
      // scroll-to-find flaky against a virtualized ListView.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(520, 3000);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        testApp(
          overrides: _overrides(),
          child: SizedBox(
            width: 520,
            height: 3000,
            child: Column(
              children: [
                const SizedBox(height: 250, child: PlanProfileChart()),
                const ContingencyChips(),
                Expanded(
                  child: PlanResultsSheet(controller: ScrollController()),
                ),
              ],
            ),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanProfileChart)),
      );
      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
      notifier.addTank(
        const DiveTank(
          id: 'deco',
          volume: 11.1,
          startPressure: 200,
          gasMix: GasMix(o2: 50),
          role: TankRole.deco,
        ),
      );
      await tester.pumpAndSettle();

      PlanChartSeriesPainter seriesPainter() =>
          tester
                  .widget<CustomPaint>(find.byKey(const Key('planChartSeries')))
                  .painter
              as PlanChartSeriesPainter;
      expect(seriesPainter().ghost, isNull);

      await tester.tap(find.text('CONTINGENCIES'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lost EAN50'));
      await tester.pumpAndSettle();

      expect(container.read(selectedLostGasTankIdProvider), 'deco');
      expect(seriesPainter().ghost, isNotNull);
      // Selecting a row for preview does not affect its own collapse state.
      expect(
        container.read(collapsedContingencyKeysProvider),
        isNot(contains('deco')),
      );

      // Tapping again deselects.
      await tester.tap(find.text('Lost EAN50'));
      await tester.pumpAndSettle();
      expect(container.read(selectedLostGasTankIdProvider), isNull);
      expect(seriesPainter().ghost, isNull);

      // Collapsing the row hides its runtime table but keeps the chip. The
      // chevron is a 20px glyph, so it needs a box around it to stay
      // tappable: the theme's padded tap target (48) trimmed by compact
      // density (-8).
      final chevron = find.ancestor(
        of: find.byIcon(Icons.expand_more).last,
        matching: find.byType(IconButton),
      );
      expect(tester.getSize(chevron).height, greaterThanOrEqualTo(40));
      expect(tester.getSize(chevron).width, greaterThanOrEqualTo(40));
      await tester.tap(find.byIcon(Icons.expand_more).last);
      await tester.pumpAndSettle();
      expect(
        container.read(collapsedContingencyKeysProvider),
        contains('deco'),
      );
      expect(find.text('Lost EAN50'), findsOneWidget);

      // Re-expand, re-select, then pick a deviation chip -- only one
      // ghost/preview at a time.
      await tester.tap(find.byIcon(Icons.chevron_right).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lost EAN50'));
      await tester.pumpAndSettle();
      expect(container.read(selectedLostGasTankIdProvider), 'deco');

      await tester.tap(
        find.descendant(
          of: find.byType(ContingencyChips),
          matching: find.text('+5m'),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(selectedLostGasTankIdProvider), isNull);
      expect(container.read(selectedDeviationProvider), 'deeper');
      expect(seriesPainter().ghost, isNotNull);
    },
  );

  testWidgets('settings section edits deltas, turn rule, and custom fraction', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: _overrides(),
        child: const SizedBox(
          width: 500,
          child: SingleChildScrollView(child: ContingencySettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContingencySettingsSection)),
    );

    // Depth delta and time delta are PlanNumberField (plain TextField,
    // issue #3552); the turn-pressure fraction below still uses the older
    // NumberField (TextFormField).
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '8');
    await tester.enterText(fields.at(1), '12');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).deviationDepthDelta, 8.0);
    expect(container.read(divePlanNotifierProvider).deviationTimeMinutes, 12);

    // Pick a turn-pressure rule from the dropdown.
    await tester.tap(
      find.byType(DropdownButtonFormField<domain.TurnPressureRule?>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thirds').last);
    await tester.pumpAndSettle();
    expect(
      container.read(divePlanNotifierProvider).turnPressureRule,
      domain.TurnPressureRule.thirds,
    );

    // Custom exposes a fraction field.
    await tester.tap(
      find.byType(DropdownButtonFormField<domain.TurnPressureRule?>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();
    final fractionField = find.byType(TextFormField).last;
    await tester.enterText(fractionField, '0.4');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).turnPressureFraction, 0.4);
  });
}
