import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/range_table_service.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_result_status.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/planner_results.dart';
import '../../../../helpers/test_app.dart';

const _calculating = 'Calculating';
const _updating = 'Updating';
const _failed = 'Could not be calculated';

Finder _bailout() => find.byType(PlanResultSection<BailoutOutcome>);
Finder _rangeTable() => find.byType(PlanResultSection<RangeTable>);
Finder _contingencies() => find.byType(PlanResultSection<List<Widget>>);

Finder _status(Finder section, String text) =>
    find.descendant(of: section, matching: find.text(text));

Finder _dimmed(Finder section) =>
    find.descendant(of: section, matching: find.byType(Opacity));

void main() {
  late HeldPlanResultRunner runner;

  /// Mounts the sheet with a CCR plan, every first run held.
  Future<ProviderContainer> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    runner = HeldPlanResultRunner();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          planResultsSettleDelayProvider.overrideWithValue(Duration.zero),
          planResultRunnerProvider.overrideWithValue(runner),
        ],
        child: PlanResultsSheet(controller: ScrollController()),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanResultsSheet)),
    );
    container.read(divePlanNotifierProvider.notifier)
      ..addSimplePlan(maxDepth: 30, bottomTimeMinutes: 25)
      ..updateMode(domain.PlanMode.ccr)
      ..addTank(
        const DiveTank(
          id: 'bo',
          volume: 11.1,
          startPressure: 207,
          gasMix: GasMix(o2: 50),
          role: TankRole.bailout,
        ),
      );
    await settle(tester);
    return container;
  }

  Future<ProviderContainer> mountExpanded(WidgetTester tester) async {
    final container = await mount(tester);
    container.read(contingenciesExpandedProvider.notifier).state = true;
    await settle(tester);
    return container;
  }

  Future<void> finish(WidgetTester tester, Object computation) async {
    runner.latest(computation).finish();
    await settle(tester);
  }

  Future<void> fail(WidgetTester tester, Object computation) async {
    runner.latest(computation).fail(StateError('engine'));
    await settle(tester);
  }

  void edit(ProviderContainer container) {
    final notifier = container.read(divePlanNotifierProvider.notifier);
    final bottom = container.read(divePlanNotifierProvider).segments.last;
    notifier.updateSegment(
      bottom.id,
      bottom.copyWith(durationSeconds: bottom.durationSeconds + 60),
    );
  }

  for (final (name, section, computation) in [
    ('bailout', _bailout, computeBailout as Object),
    ('range table', _rangeTable, computeRangeTable as Object),
  ]) {
    group('$name section', () {
      testWidgets('a first result pending says calculating', (tester) async {
        await mount(tester);

        expect(_status(section(), _calculating), findsOneWidget);
        expect(_dimmed(section()), findsNothing);
      });

      testWidgets('a current result is plain', (tester) async {
        await mount(tester);
        await finish(tester, computation);

        expect(_status(section(), _calculating), findsNothing);
        expect(_status(section(), _updating), findsNothing);
        expect(_dimmed(section()), findsNothing);
      });

      testWidgets('a newer result pending dims the last figures', (
        tester,
      ) async {
        final container = await mount(tester);
        await finish(tester, computation);

        edit(container);
        await settle(tester);

        expect(_status(section(), _updating), findsOneWidget);
        expect(_dimmed(section()), findsOneWidget);
      });

      testWidgets('a failure with nothing to show says so', (tester) async {
        await mount(tester);
        await fail(tester, computation);

        expect(_status(section(), _failed), findsOneWidget);
        expect(_dimmed(section()), findsNothing);
      });

      testWidgets('a failure keeps the last figures dimmed', (tester) async {
        final container = await mount(tester);
        await finish(tester, computation);
        edit(container);
        await settle(tester);

        await fail(tester, computation);

        expect(_status(section(), _failed), findsOneWidget);
        expect(_dimmed(section()), findsOneWidget);
      });
    });
  }

  group('contingency section', () {
    testWidgets('collapsed shows no status and runs nothing', (tester) async {
      await mount(tester);

      expect(_contingencies(), findsNothing);
      expect(
        runner.held.map((run) => run.computation),
        isNot(contains(computeDeviations)),
      );
    });

    testWidgets('opening it says calculating, not updating', (tester) async {
      await mountExpanded(tester);

      expect(_status(_contingencies(), _calculating), findsOneWidget);
      expect(_status(_contingencies(), _updating), findsNothing);
    });

    testWidgets('a current result is plain', (tester) async {
      await mountExpanded(tester);
      await finish(tester, computeDeviations);
      await finish(tester, computeLostGas);

      expect(_status(_contingencies(), _calculating), findsNothing);
      expect(_status(_contingencies(), _updating), findsNothing);
      expect(_dimmed(_contingencies()), findsNothing);
    });

    testWidgets('one table still pending keeps the section marked', (
      tester,
    ) async {
      await mountExpanded(tester);
      await finish(tester, computeDeviations);

      // There are rows now, so this is an update to them, not a first answer.
      expect(_status(_contingencies(), _updating), findsOneWidget);
      expect(_dimmed(_contingencies()), findsOneWidget);
    });

    testWidgets('a newer result pending dims the rows', (tester) async {
      final container = await mountExpanded(tester);
      await finish(tester, computeDeviations);
      await finish(tester, computeLostGas);

      edit(container);
      await settle(tester);

      expect(_status(_contingencies(), _updating), findsOneWidget);
      expect(_dimmed(_contingencies()), findsOneWidget);
    });

    testWidgets('a failure with nothing to show says so', (tester) async {
      await mountExpanded(tester);
      await fail(tester, computeDeviations);
      await fail(tester, computeLostGas);

      expect(_status(_contingencies(), _failed), findsOneWidget);
      expect(_dimmed(_contingencies()), findsNothing);
    });

    testWidgets('one table failing marks the section and keeps its rows', (
      tester,
    ) async {
      await mountExpanded(tester);
      await finish(tester, computeDeviations);
      await fail(tester, computeLostGas);

      expect(_status(_contingencies(), _failed), findsOneWidget);
      expect(_dimmed(_contingencies()), findsOneWidget);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}
