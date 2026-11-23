import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/contingency_selection.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/planner_results.dart';
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

const _ean50 = DiveTank(
  id: 'ean50',
  volume: 11.1,
  startPressure: 200,
  gasMix: GasMix(o2: 50),
  role: TankRole.deco,
);
const _o2 = DiveTank(
  id: 'o2',
  volume: 11.1,
  startPressure: 200,
  gasMix: GasMix(o2: 100),
  role: TankRole.deco,
);

Future<ProviderContainer> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...plannerResultsInline(),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
      child: const SizedBox(
        width: 800,
        child: Column(children: [ContingencyChips(), ContingencyPreviewChip()]),
      ),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ContingencyChips)),
  );
  final notifier = container.read(divePlanNotifierProvider.notifier);
  notifier.addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
  notifier.addTank(_ean50);
  notifier.addTank(_o2);
  await tester.pumpAndSettle();
  return container;
}

Finder _chip(String label) => find.descendant(
  of: find.byType(ContingencyChips),
  matching: find.text(label),
);

void main() {
  testWidgets('the bar offers +depth, +time and one chip per losable gas, '
      'without a combined deviation chip', (tester) async {
    await _pump(tester);

    expect(_chip('Base'), findsOneWidget);
    expect(_chip('+5m'), findsOneWidget);
    expect(_chip('+5′'), findsOneWidget);
    expect(_chip('+5m +5′'), findsNothing);
    expect(_chip('Lost EAN50'), findsOneWidget);
    expect(_chip('Lost O2'), findsOneWidget);
  });

  testWidgets('+depth and +time toggle independently and combine', (
    tester,
  ) async {
    final container = await _pump(tester);

    await tester.tap(_chip('+5m'));
    await tester.tap(_chip('+5′'));
    await tester.pumpAndSettle();

    expect(
      container.read(contingencySelectionProvider),
      const ContingencySelection(deeper: true, longer: true),
    );
    expect(find.text('Previewing: +5m +5′'), findsOneWidget);

    await tester.tap(_chip('+5m'));
    await tester.pumpAndSettle();
    expect(
      container.read(contingencySelectionProvider),
      const ContingencySelection(longer: true),
    );
    expect(find.text('Previewing: +5′'), findsOneWidget);
  });

  testWidgets('lost gases combine with each other and with a deviation', (
    tester,
  ) async {
    final container = await _pump(tester);

    await tester.tap(_chip('+5m'));
    await tester.tap(_chip('Lost EAN50'));
    await tester.tap(_chip('Lost O2'));
    await tester.pumpAndSettle();

    final preview = container.read(selectedContingencyProvider)!;
    expect(preview.lostTanks.map((t) => t.id), ['ean50', 'o2']);
    expect(preview.outcome.maxDepth, closeTo(50, 0.01));
    expect(find.text('Previewing: +5m · Lost EAN50 · Lost O2'), findsOneWidget);

    await tester.tap(_chip('Lost EAN50'));
    await tester.pumpAndSettle();
    expect(
      container.read(selectedContingencyProvider)!.lostTanks.map((t) => t.id),
      ['o2'],
    );
    expect(container.read(contingencySelectionProvider).deeper, isTrue);
  });

  testWidgets('Base clears every toggle', (tester) async {
    final container = await _pump(tester);

    await tester.tap(_chip('+5m'));
    await tester.tap(_chip('+5′'));
    await tester.tap(_chip('Lost O2'));
    await tester.pumpAndSettle();
    expect(container.read(selectedContingencyProvider), isNotNull);

    await tester.tap(_chip('Base'));
    await tester.pumpAndSettle();
    expect(
      container.read(contingencySelectionProvider),
      ContingencySelection.none,
    );
    expect(container.read(selectedContingencyProvider), isNull);
    expect(find.textContaining('Previewing'), findsNothing);
  });

  for (final mode in [
    domain.PlanMode.ccr,
    domain.PlanMode.scr,
    domain.PlanMode.pscr,
  ]) {
    testWidgets('${mode.name} plans offer no lost-gas chips', (tester) async {
      final container = await _pump(tester);

      container.read(divePlanNotifierProvider.notifier).updateMode(mode);
      await tester.pumpAndSettle();

      expect(_chip('+5m'), findsOneWidget);
      expect(_chip('Lost EAN50'), findsNothing);
      expect(_chip('Lost O2'), findsNothing);
    });
  }

  testWidgets('reopening the same plan starts at Base', (tester) async {
    final container = await _pump(tester);

    await tester.tap(_chip('+5m'));
    await tester.tap(_chip('Lost EAN50'));
    await tester.pumpAndSettle();

    final notifier = container.read(divePlanNotifierProvider.notifier);
    // A reopen loads a fresh copy of the saved plan, same id.
    notifier.loadPlan(container.read(divePlanNotifierProvider).copyWith());
    await tester.pumpAndSettle();

    expect(
      container.read(contingencySelectionProvider),
      ContingencySelection.none,
    );
    expect(find.textContaining('Previewing'), findsNothing);
  });

  testWidgets('no entry point can mark every cylinder lost', (tester) async {
    // The results pane toggles through the notifier directly, without the
    // chip bar's disabled state, so the guard has to live there.
    final container = await _pump(tester);
    final plan = container.read(divePlanNotifierProvider.notifier);
    final back = container.read(divePlanNotifierProvider).tanks.first;
    plan.updateTank(back.id, back.copyWith(isTravelGas: true));
    await tester.pumpAndSettle();

    final selection = container.read(contingencySelectionProvider.notifier);
    selection.toggleLostGas(back.id);
    selection.toggleLostGas('ean50');
    selection.toggleLostGas('o2');

    expect(container.read(contingencySelectionProvider).lostTankIds, {
      back.id,
      'ean50',
    });
  });

  testWidgets('opening another plan clears every toggle', (tester) async {
    final container = await _pump(tester);

    await tester.tap(_chip('+5m'));
    await tester.tap(_chip('Lost EAN50'));
    await tester.pumpAndSettle();

    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.newPlan();
    notifier.addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();

    expect(
      container.read(contingencySelectionProvider),
      ContingencySelection.none,
    );
    expect(find.textContaining('Previewing'), findsNothing);
  });

  testWidgets('switching to CCR and back does not bring lost gases back', (
    tester,
  ) async {
    final container = await _pump(tester);

    await tester.tap(_chip('Lost O2'));
    await tester.pumpAndSettle();

    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.updateMode(domain.PlanMode.ccr);
    await tester.pumpAndSettle();
    notifier.updateMode(domain.PlanMode.oc);
    await tester.pumpAndSettle();

    expect(
      container.read(contingencySelectionProvider),
      ContingencySelection.none,
    );
    expect(find.textContaining('Previewing'), findsNothing);
  });

  testWidgets('a lost-gas chip that would leave nothing to breathe is '
      'disabled', (tester) async {
    final container = await _pump(tester);
    final notifier = container.read(divePlanNotifierProvider.notifier);
    final back = container.read(divePlanNotifierProvider).tanks.first;
    notifier.updateTank(back.id, back.copyWith(isTravelGas: true));
    await tester.pumpAndSettle();
    final backChip = _chip('Lost ${back.gasMix.name}');
    expect(backChip, findsOneWidget);

    await tester.tap(_chip('+5m'));
    await tester.tap(backChip);
    await tester.tap(_chip('Lost EAN50'));
    await tester.pumpAndSettle();

    // Only the O2 is left: losing it too would leave no cylinder at all.
    await tester.tap(_chip('Lost O2'));
    await tester.pumpAndSettle();
    expect(container.read(contingencySelectionProvider).lostTankIds, {
      back.id,
      'ean50',
    });
    expect(
      find.text(
        'Previewing: +5m · Lost ${back.gasMix.name} · '
        'Lost EAN50',
      ),
      findsOneWidget,
    );
  });

  testWidgets('losing the bottom drops +time but keeps the other toggles', (
    tester,
  ) async {
    final container = await _pump(tester);

    await tester.tap(_chip('+5m'));
    await tester.tap(_chip('+5′'));
    await tester.tap(_chip('Lost EAN50'));
    await tester.pumpAndSettle();

    final notifier = container.read(divePlanNotifierProvider.notifier);
    final hold = container.read(divePlanNotifierProvider).segments.last;
    notifier.removeSegment(hold.id);
    await tester.pumpAndSettle();

    expect(_chip('+5′'), findsNothing);
    expect(
      container.read(contingencySelectionProvider),
      const ContingencySelection(deeper: true, lostTankIds: {'ean50'}),
    );
    expect(find.text('Previewing: +5m · Lost EAN50'), findsOneWidget);
  });
}
