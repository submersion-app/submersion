import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/planner/presentation/widgets/ccr_settings_section.dart';
import 'package:submersion/features/planner/presentation/widgets/ccr_setpoint_control.dart';
import 'package:submersion/features/planner/presentation/widgets/ccr_switch_depth_control.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/planner_results.dart';
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
    ...plannerResultsInline(),
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
        gasMix: GasMix(o2: 28),
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
        gasMix: GasMix(o2: 28),
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
      matching: find.byType(SingleChildScrollView),
    );
    expect(gasList, findsOneWidget);
    // Diluent + oxygen supply in the main list, plus the single bailout
    // cylinder's own per-cylinder row in the bailout section.
    expect(find.textContaining('used:'), findsNWidgets(3));
  });

  testWidgets('a bailout cylinder an authored OC segment breathes joins the '
      'main gas list, so the gas it spent is visible (#3898)', (tester) async {
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
        gasMix: GasMix(o2: 28),
        role: TankRole.bailout,
      ),
    );
    final bottom = container.read(divePlanNotifierProvider).segments.last;
    notifier.updateSegment(
      bottom.id,
      bottom.copyWith(
        tankId: 'bo',
        gasMix: const GasMix(o2: 28),
        diveModeOverride: domain.PlanMode.oc,
      ),
    );
    await tester.pumpAndSettle();

    // The two loop slots and the bailout cylinder in the main list, plus
    // that cylinder's worst-case row in the bailout section.
    expect(find.textContaining('used:'), findsNWidgets(4));
  });

  // The CCR section's three controls, stacked: setpoint low, setpoint high,
  // switch depth (issue #3793).
  Finder control(int index) => index == 2
      ? find.byType(CcrSwitchDepthControl)
      : find.byType(CcrSetpointControl).at(index);

  Finder choice(Finder within, String label) =>
      find.descendant(of: within, matching: find.text(label));

  Future<ProviderContainer> pumpSection(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    double width = 500,
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...plannerResultsInline(),
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(settings),
          ),
        ],
        child: SingleChildScrollView(
          child: SizedBox(width: width, child: const CcrSettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(CcrSettingsSection)),
    );
  }

  const settingsWithCcr = AppSettings(
    ccrSetpointLow: 0.6,
    ccrSetpointHigh: 1.2,
    ccrSetpointSwitchDepth: 12.0,
  );

  testWidgets('Default shows the Settings setpoints and switch depth as read '
      'only text, with no number field', (tester) async {
    final container = await pumpSection(tester, settings: settingsWithCcr);

    expect(find.text('0.6 bar'), findsOneWidget);
    expect(find.text('1.2 bar'), findsOneWidget);
    expect(find.text('12m'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    final state = container.read(divePlanNotifierProvider);
    expect(state.setpointLow, isNull);
    expect(state.setpointHigh, isNull);
    expect(state.setpointSwitchDepth, isNull);
    expect(state.setpointSwitchOff, isFalse);
  });

  testWidgets('Default shows the Settings switch depth in the diver\'s unit', (
    tester,
  ) async {
    await pumpSection(
      tester,
      settings: settingsWithCcr.copyWith(depthUnit: DepthUnit.feet),
    );

    // 12 m is 39.37 ft: not a whole number, so one decimal.
    expect(find.text('39.4ft'), findsOneWidget);
    expect(find.text('12m'), findsNothing);
  });

  testWidgets('a setpoint Custom starts at the Settings value, edits write '
      'the plan, Default clears it again', (tester) async {
    final container = await pumpSection(tester, settings: settingsWithCcr);

    await tester.tap(choice(control(0), 'Custom'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).setpointLow, 0.6);
    // The other setpoint is untouched.
    expect(container.read(divePlanNotifierProvider).setpointHigh, isNull);
    final field = find.descendant(
      of: control(0),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(field).controller!.text, '0.6');

    await tester.enterText(field, '0.8');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).setpointLow, 0.8);

    // Out of range text is not committed until focus leaves the box.
    await tester.enterText(field, '0');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).setpointLow, 0.8);

    await tester.tap(choice(control(0), 'Default'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).setpointLow, isNull);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(choice(control(1), 'Custom'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).setpointHigh, 1.2);
    await tester.tap(choice(control(1), 'Default'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).setpointHigh, isNull);
  });

  testWidgets('a plan that carries its own setpoints shows Custom with them', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...plannerResultsInline(),
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(settingsWithCcr),
          ),
        ],
        child: const SingleChildScrollView(
          child: SizedBox(width: 500, child: CcrSettingsSection()),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CcrSettingsSection)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .updateSetpoints(low: 0.9, high: 1.5, switchDepth: 20);
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    expect(tester.widget<TextField>(fields.at(0)).controller!.text, '0.9');
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, '1.5');
    expect(tester.widget<TextField>(fields.at(2)).controller!.text, '20');
  });

  testWidgets('switch depth Custom starts at the Settings depth and accepts '
      '0; Off keeps the depth; Default clears both', (tester) async {
    final container = await pumpSection(tester, settings: settingsWithCcr);
    final depth = control(2);

    await tester.tap(choice(depth, 'Custom'));
    await tester.pumpAndSettle();
    var state = container.read(divePlanNotifierProvider);
    expect(state.setpointSwitchDepth, 12.0);
    expect(state.setpointSwitchOff, isFalse);
    final field = find.descendant(of: depth, matching: find.byType(TextField));
    expect(tester.widget<TextField>(field).controller!.text, '12');

    await tester.enterText(field, '18');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).setpointSwitchDepth, 18.0);

    // 0 (high setpoint from the surface) is a valid depth.
    await tester.enterText(field, '0');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).setpointSwitchDepth, 0.0);

    await tester.enterText(field, '18');
    await tester.pumpAndSettle();
    await tester.tap(choice(depth, 'Off'));
    await tester.pumpAndSettle();
    state = container.read(divePlanNotifierProvider);
    expect(state.setpointSwitchOff, isTrue);
    expect(state.setpointSwitchDepth, 18.0);
    expect(
      find.text('No switch by depth: low setpoint throughout'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);

    // Custom again brings back the depth that was kept.
    await tester.tap(choice(depth, 'Custom'));
    await tester.pumpAndSettle();
    state = container.read(divePlanNotifierProvider);
    expect(state.setpointSwitchOff, isFalse);
    expect(state.setpointSwitchDepth, 18.0);

    await tester.tap(choice(depth, 'Off'));
    await tester.pumpAndSettle();
    await tester.tap(choice(depth, 'Default'));
    await tester.pumpAndSettle();
    state = container.read(divePlanNotifierProvider);
    expect(state.setpointSwitchOff, isFalse);
    expect(state.setpointSwitchDepth, isNull);
    expect(find.text('12m'), findsOneWidget);
  });

  testWidgets('switch depth Custom edits in feet and stores meters', (
    tester,
  ) async {
    final container = await pumpSection(
      tester,
      settings: settingsWithCcr.copyWith(depthUnit: DepthUnit.feet),
    );

    await tester.tap(choice(control(2), 'Custom'));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: control(2),
      matching: find.byType(TextField),
    );
    // The Settings depth, 12 m, in feet.
    expect(tester.widget<TextField>(field).controller!.text, '39.4');
    expect(find.text('ft'), findsWidgets);

    await tester.enterText(field, '40');
    await tester.pumpAndSettle();
    expect(
      container.read(divePlanNotifierProvider).setpointSwitchDepth,
      closeTo(12.192, 0.001),
    );
  });

  testWidgets('the controls stack and stay readable on a narrow screen', (
    tester,
  ) async {
    final container = await pumpSection(
      tester,
      settings: settingsWithCcr,
      width: 300,
    );
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.updateSetpoints(low: 0.9, high: 1.5, switchDepth: 20);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final tops = [for (var i = 0; i < 3; i++) tester.getTopLeft(control(i)).dy];
    expect(tops[1], greaterThan(tops[0]));
    expect(tops[2], greaterThan(tops[1]));
  });
}
