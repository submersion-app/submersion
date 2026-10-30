import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/widgets/ccr_settings_section.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier([super.state = const AppSettings()]);

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  void replace(AppSettings settings) => state = settings;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  List<dynamic> overrides() => [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
  ];

  testWidgets('badge cycles OC -> CCR -> SCR -> PSCR -> OC', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testApp(overrides: overrides(), child: const PlanCanvasPage()),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanCanvasPage)),
    );
    expect(find.text('OC'), findsOneWidget);

    await tester.tap(find.text('OC'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).mode, domain.PlanMode.ccr);
    expect(find.text('CCR'), findsOneWidget);

    await tester.tap(find.text('CCR'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).mode, domain.PlanMode.scr);
    expect(find.text('SCR'), findsOneWidget);

    await tester.tap(find.text('SCR'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).mode, domain.PlanMode.pscr);
    expect(find.text('PSCR'), findsOneWidget);

    await tester.tap(find.text('PSCR'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).mode, domain.PlanMode.oc);
    expect(find.text('OC'), findsOneWidget);
  });

  testWidgets('CCR plan with bailout tank shows the bailout section', (
    tester,
  ) async {
    // The sheet is a ListView and the bailout section is the last thing in
    // it, so the 500x700 box below has to actually be 700 tall - on the
    // default 800x600 surface the section lands in the cache region and the
    // finders skip it as offstage.
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testApp(
        overrides: overrides(),
        child: SizedBox(
          width: 500,
          height: 700,
          child: PlanResultsSheet(controller: ScrollController()),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanResultsSheet)),
    );
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    notifier.updateMode(domain.PlanMode.ccr);
    notifier.addTank(
      const DiveTank(
        id: 'bo',
        volume: 11.1,
        startPressure: 207,
        gasMix: GasMix(o2: 50),
        role: TankRole.bailout,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Bailout'), findsWidgets);
    expect(find.textContaining('Worst case'), findsOneWidget);
    expect(find.textContaining('Required'), findsOneWidget);
    // Required/available volumes respect the diver's volume unit (default L).
    expect(find.textContaining(RegExp(r'Required \d+ L')), findsOneWidget);
    // The bailout tank carries no normal-loop consumption to chart in the
    // per-tank gas list -- it belongs in the bailout section instead (#3137
    // follow-up). The two loop slots -- the diluent and the oxygen supply
    // entering CCR added -- each get a "used: ..." row there (#3220), plus
    // one more for the single bailout cylinder's own per-cylinder row in
    // the bailout section, read the same way as the main list.
    expect(find.textContaining('used:'), findsNWidgets(3));
  });

  testWidgets('the oxygen slot is loop consumption, listed in the main gas '
      'list next to the diluent (#3220)', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testApp(
        overrides: overrides(),
        child: SizedBox(
          width: 500,
          height: 700,
          child: PlanResultsSheet(controller: ScrollController()),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanResultsSheet)),
    );
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    notifier.updateMode(domain.PlanMode.ccr);
    notifier.addTank(
      const DiveTank(
        id: 'bo',
        volume: 11.1,
        startPressure: 207,
        gasMix: GasMix(o2: 50),
        role: TankRole.bailout,
      ),
    );
    final o2 = container
        .read(divePlanNotifierProvider)
        .tanks
        .firstWhere((t) => t.role == TankRole.oxygenSupply);
    notifier.updateTank(o2.id, o2.copyWith(name: 'Onboard O2'));
    await tester.pumpAndSettle();

    expect(find.text('Onboard O2'), findsOneWidget);
    final gasList = find.ancestor(
      of: find.text('Onboard O2'),
      matching: find.byType(ListView),
    );
    expect(gasList, findsOneWidget);
    // Diluent + oxygen supply in the main list, plus the single bailout
    // cylinder's own per-cylinder row in the bailout section.
    expect(find.textContaining('used:'), findsNWidgets(3));
  });

  testWidgets('CCR settings edit all setpoints; switch depth accepts 0', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: overrides(),
        child: const SizedBox(width: 500, child: CcrSettingsSection()),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CcrSettingsSection)),
    );
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), '0.8');
    await tester.enterText(fields.at(1), '1.5');
    await tester.enterText(fields.at(2), '15');
    await tester.pumpAndSettle();
    final state = container.read(divePlanNotifierProvider);
    expect(state.setpointLow, 0.8);
    expect(state.setpointHigh, 1.5);
    expect(state.setpointSwitchDepth, 15.0);

    // Switch depth 0 (high setpoint from the surface) is a valid config.
    await tester.enterText(fields.at(2), '0');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).setpointSwitchDepth, 0.0);

    // Out of range (below the practical minimum) is not committed until
    // focus leaves the field, which this test never triggers, so the prior
    // value stays untouched.
    await tester.enterText(fields.at(0), '0');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).setpointLow, 0.8);
  });

  testWidgets(
    'an empty setpoint field follows the diver\'s Settings as a greyed '
    'hint, not the spec 0.7 / 1.3 (issues #2801, #3552)',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _TestSettingsNotifier(
                const AppSettings(ccrSetpointLow: 0.6, ccrSetpointHigh: 1.2),
              ),
            ),
          ],
          child: const SizedBox(width: 500, child: CcrSettingsSection()),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CcrSettingsSection)),
      );
      // A plan that reached CCR without the mode switch's seed (an imported
      // file, or one saved before the seed existed) carries no setpoints.
      expect(container.read(divePlanNotifierProvider).setpointLow, isNull);
      expect(container.read(divePlanNotifierProvider).setpointHigh, isNull);

      final fields = find.byType(TextField);
      // Empty text, with the Settings value shown only as the hint - the
      // same visible distinction every other overridable Setup field uses.
      expect(tester.widget<TextField>(fields.at(0)).controller!.text, '');
      expect(
        tester.widget<TextField>(fields.at(0)).decoration?.hintText,
        '0.6',
      );
      expect(tester.widget<TextField>(fields.at(1)).controller!.text, '');
      expect(
        tester.widget<TextField>(fields.at(1)).decoration?.hintText,
        '1.2',
      );
    },
  );

  testWidgets(
    'an unset setpoint field\'s hint follows a Settings change; a set one '
    'keeps its own value (issues #2801, #3552)',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _TestSettingsNotifier(
                const AppSettings(ccrSetpointLow: 0.6, ccrSetpointHigh: 1.2),
              ),
            ),
          ],
          child: const SizedBox(width: 500, child: CcrSettingsSection()),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CcrSettingsSection)),
      );
      container
          .read(divePlanNotifierProvider.notifier)
          .updateSetpoints(low: 0.9);

      (container.read(settingsProvider.notifier) as _TestSettingsNotifier)
          .replace(
            const AppSettings(ccrSetpointLow: 0.5, ccrSetpointHigh: 1.4),
          );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      // The low field now carries the plan's own override text; a plan
      // value is never overwritten by a Settings change.
      expect(tester.widget<TextField>(fields.at(0)).controller!.text, '0.9');
      // The high field is still unset, so its hint follows the new Settings
      // value.
      expect(tester.widget<TextField>(fields.at(1)).controller!.text, '');
      expect(
        tester.widget<TextField>(fields.at(1)).decoration?.hintText,
        '1.4',
      );
    },
  );

  testWidgets(
    'clearing an override leaves the field empty, following Settings again '
    '(issues #2801, #3552)',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _TestSettingsNotifier(
                const AppSettings(ccrSetpointLow: 0.6, ccrSetpointHigh: 1.2),
              ),
            ),
          ],
          child: const SizedBox(width: 500, child: CcrSettingsSection()),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CcrSettingsSection)),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '1.5');
      await tester.pumpAndSettle();
      expect(container.read(divePlanNotifierProvider).setpointHigh, 1.5);

      // Blank text clears the override back to "follow Settings".
      await tester.enterText(fields.at(1), '');
      await tester.pumpAndSettle();
      expect(container.read(divePlanNotifierProvider).setpointHigh, isNull);

      (container.read(settingsProvider.notifier) as _TestSettingsNotifier)
          .replace(
            const AppSettings(ccrSetpointLow: 0.6, ccrSetpointHigh: 1.4),
          );
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(fields.at(1)).controller!.text, '');
      expect(
        tester.widget<TextField>(fields.at(1)).decoration?.hintText,
        '1.4',
      );
    },
  );

  testWidgets('CCR settings fields stay in a row when there is room, and stack '
      'vertically when there is not (#3130)', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: overrides(),
        child: const SizedBox(width: 500, child: CcrSettingsSection()),
      ),
    );
    await tester.pumpAndSettle();
    final wideFields = find.byType(TextField);
    expect(wideFields, findsNWidgets(3));
    // Side by side: all three share the same top edge.
    final wideTops = [
      for (var i = 0; i < 3; i++) tester.getTopLeft(wideFields.at(i)).dy,
    ];
    expect(wideTops[1], wideTops[0]);
    expect(wideTops[2], wideTops[0]);

    await tester.pumpWidget(
      testApp(
        overrides: overrides(),
        child: const SizedBox(width: 300, child: CcrSettingsSection()),
      ),
    );
    await tester.pumpAndSettle();
    final narrowFields = find.byType(TextField);
    expect(narrowFields, findsNWidgets(3));
    // Stacked: each field starts strictly below the one before it, so
    // every label keeps the field's full width instead of being
    // ellipsis-truncated.
    final narrowTops = [
      for (var i = 0; i < 3; i++) tester.getTopLeft(narrowFields.at(i)).dy,
    ];
    expect(narrowTops[1], greaterThan(narrowTops[0]));
    expect(narrowTops[2], greaterThan(narrowTops[1]));
  });
}
