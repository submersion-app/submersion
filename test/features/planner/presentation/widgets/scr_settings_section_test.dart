import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/presentation/widgets/loop_flow_summary.dart';
import 'package:submersion/features/planner/presentation/widgets/scr_settings_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The planner's SCR Setup section (issue #4660): the plan's own injection
/// rate and VO2, in the diver's volume unit, with the diver's defaults as
/// hints.
void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    double width = 500,
  }) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(settings),
          ),
        ],
        child: SizedBox(width: width, child: const ScrSettingsSection()),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScrSettingsSection)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .updateMode(domain.PlanMode.scr);
    await tester.pumpAndSettle();
    return container;
  }

  TextField field(WidgetTester tester, int index) =>
      tester.widget<TextField>(find.byType(TextField).at(index));

  testWidgets('empty fields show the diver defaults as hints in L/min', (
    tester,
  ) async {
    await pump(
      tester,
      settings: const AppSettings(
        plannerScrInjectionRate: 7.5,
        plannerScrVo2: 1.3,
      ),
    );
    expect(find.byType(TextField), findsNWidgets(2));
    expect(field(tester, 0).controller!.text, '');
    expect(field(tester, 0).decoration?.hintText, '7.5');
    expect(field(tester, 1).controller!.text, '');
    expect(field(tester, 1).decoration?.hintText, '1.3');
    expect(find.text('L/min'), findsNWidgets(2));
  });

  testWidgets('an imperial diver sees cuft/min hints', (tester) async {
    await pump(
      tester,
      settings: const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
    );
    // One place finer than an RMV: a cuft/min step is 0.03 L/min, not 0.28.
    expect(field(tester, 0).decoration?.hintText, '0.424');
    expect(field(tester, 1).decoration?.hintText, '0.046');
    expect(find.text('cuft/min'), findsNWidgets(2));
  });

  testWidgets('typing a rate stores it on the plan in L/min', (tester) async {
    final container = await pump(tester);
    await tester.enterText(find.byType(TextField).at(0), '7.5');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).scrInjectionRate, 7.5);
  });

  testWidgets('clearing a field returns it to the diver default', (
    tester,
  ) async {
    final container = await pump(tester);
    await tester.enterText(find.byType(TextField).at(1), '2.0');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).scrVo2, 2.0);

    await tester.enterText(find.byType(TextField).at(1), '');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).scrVo2, isNull);
  });

  testWidgets(
    'an imperial diver retyping the VO2 hint stores about 1.3 L/min',
    (tester) async {
      final container = await pump(
        tester,
        settings: const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
      );
      await tester.enterText(find.byType(TextField).at(1), '0.046');
      await tester.enterText(find.byType(TextField).at(0), '0.265');
      await tester.pumpAndSettle();
      expect(
        container.read(divePlanNotifierProvider).scrVo2,
        closeTo(1.3, 0.01),
      );
      // A Ray nozzle typed in cuft/min keeps what was typed.
      expect(
        container.read(divePlanNotifierProvider).scrInjectionRate,
        closeTo(7.5, 0.01),
      );
      expect(field(tester, 0).controller!.text, '0.265');
    },
  );

  testWidgets('the fields stack on a narrow pane, as the CCR section does', (
    tester,
  ) async {
    await pump(tester, width: 300);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    final first = tester.getTopLeft(fields.at(0));
    final second = tester.getTopLeft(fields.at(1));
    expect(second.dy, greaterThan(first.dy));
    expect(second.dx, first.dx);
  });

  testWidgets('shows the loop summary for the plan', (tester) async {
    await pump(tester);
    expect(find.byType(LoopFlowSummary), findsOneWidget);
  });

  group('loopSupplyGas', () {
    const ean50 = GasMix(o2: 50);
    const ean32 = GasMix(o2: 32);

    domain.DivePlan state({
      List<DiveTank> tanks = const [],
      List<PlanSegment> segments = const [],
    }) => divePlanFromState(
      DivePlanState(
        id: 'p1',
        name: 'Plan',
        mode: domain.PlanMode.scr,
        tanks: tanks,
        segments: segments,
        createdAt: DateTime(2026, 11, 17),
        updatedAt: DateTime(2026, 11, 17),
      ),
    );

    test('reads the first loop segment gas', () {
      expect(
        loopSupplyGas(
          state(
            tanks: const [DiveTank(id: 't1', gasMix: ean32)],
            segments: [
              PlanSegment.hold(
                id: 's1',
                depth: 18,
                durationMinutes: 30,
                tankId: 't1',
                gasMix: ean50,
              ),
            ],
          ),
        ),
        ean50,
      );
    });

    test('falls back to the diluent cylinder with no segments', () {
      expect(
        loopSupplyGas(
          state(
            tanks: const [
              DiveTank(id: 'o2', gasMix: GasMix(o2: 100)),
              DiveTank(id: 't1', gasMix: ean32, role: TankRole.diluent),
            ],
          ),
        ),
        ean32,
      );
    });

    test('falls back to air with nothing to read', () {
      expect(loopSupplyGas(state()), const GasMix(o2: 21));
    });
  });
}
