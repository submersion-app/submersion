import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_deco_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_environment_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_gas_section.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier([super.state = const AppSettings()]);

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _imperialVolume = AppSettings(volumeUnit: VolumeUnit.cubicFeet);

/// cuft per liter, as [VolumeUnit.convert] applies it.
const _cuftPerLiter = 0.0353147;

Widget _harness(
  Widget child, {
  AppSettings settings = const AppSettings(),
  double? loggedRmv,
}) => testApp(
  // Pin English so finders on localized labels ("Must be greater than 0",
  // "Group 2", etc.) stay deterministic regardless of the platform locale.
  locale: const Locale('en'),
  overrides: [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
    if (loggedRmv != null)
      loggedAverageSacProvider.overrideWith((ref) async => loggedRmv),
  ],
  child: SingleChildScrollView(child: child),
);

/// The Semantics label wrapping the RMV slider.
String? _rmvSemanticsLabel(WidgetTester tester) => tester
    .widgetList<Semantics>(
      find.ancestor(of: find.byType(Slider), matching: find.byType(Semantics)),
    )
    .map((s) => s.properties.label)
    .firstWhere((label) => label?.startsWith('RMV') ?? false);

void main() {
  group('planWaterOptionFor', () {
    test('maps salt, fresh, custom salinity, leftover brackish, and null', () {
      expect(
        planWaterOptionFor(waterType: WaterType.salt),
        PlannerWaterType.salt,
      );
      expect(
        planWaterOptionFor(waterType: WaterType.fresh),
        PlannerWaterType.fresh,
      );
      expect(planWaterOptionFor(), PlannerWaterType.salt);
      expect(
        planWaterOptionFor(waterType: WaterType.brackish),
        PlannerWaterType.custom,
      );
      expect(
        planWaterOptionFor(waterType: WaterType.salt, salinityPpt: 20),
        PlannerWaterType.custom,
      );
    });
  });

  testWidgets('deco section renders both GF sliders at the diver settings', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanDecoSection()));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(2));
    // AppSettings defaults: GF 50/85.
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
  });

  testWidgets('dragging the GF Low slider changes gfLow and leaves gfHigh', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanDecoSection()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanDecoSection)),
    );
    expect(container.read(divePlanNotifierProvider).gfLow, 50);
    expect(container.read(divePlanNotifierProvider).gfHigh, 85);

    await tester.drag(find.byType(Slider).first, const Offset(80, 0));
    await tester.pumpAndSettle();

    final state = container.read(divePlanNotifierProvider);
    expect(state.gfLow, greaterThan(50));
    expect(state.gfLow, lessThanOrEqualTo(100));
    expect(state.gfHigh, 85);
    expect(find.text('${state.gfLow}%'), findsOneWidget);
  });

  testWidgets('dragging the GF High slider changes gfHigh and leaves gfLow', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanDecoSection()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanDecoSection)),
    );

    await tester.drag(find.byType(Slider).last, const Offset(-80, 0));
    await tester.pumpAndSettle();

    final state = container.read(divePlanNotifierProvider);
    expect(state.gfHigh, lessThan(85));
    expect(state.gfHigh, greaterThanOrEqualTo(10));
    expect(state.gfLow, 50);
    expect(find.text('${state.gfHigh}%'), findsOneWidget);
  });

  testWidgets('deco section chooses the last stop from 3, 4, 5 or 6 m', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanDecoSection()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanDecoSection)),
    );

    expect(find.text('Last stop'), findsOneWidget);
    // Labels come from UnitFormatter.formatDepth, which spells metres with no
    // space ('3m'), as everywhere else in the app.
    for (final choice in ['3m', '4m', '5m', '6m']) {
      expect(find.text(choice), findsOneWidget, reason: choice);
    }
    expect(container.read(divePlanNotifierProvider).lastStopDepth, 3.0);

    await tester.tap(find.text('6m'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).lastStopDepth, 6.0);

    await tester.tap(find.text('4m'));
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).lastStopDepth, 4.0);
  });

  testWidgets('gas section shows SAC slider and reserve field with unit', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanGasSection()));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.textContaining('bar'), findsWidgets);
  });

  testWidgets('reserve validation: zero shows error, valid updates state', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanGasSection()));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).last;
    await tester.enterText(field, '0');
    await tester.pumpAndSettle();
    expect(find.text('Must be greater than 0'), findsOneWidget);
    await tester.enterText(field, '60');
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGasSection)),
    );
    expect(container.read(divePlanNotifierProvider).reservePressure, 60);
  });

  group('RMV slider units (#1823)', () {
    testWidgets('metric runs 8-30 L/min in 1 L/min steps', (tester) async {
      await tester.pumpWidget(_harness(const PlanGasSection()));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, 8);
      expect(slider.max, 30);
      expect(slider.divisions, 22);
      expect(slider.value, 15);
      expect(slider.label, '15.0 L/min');
      expect(find.text('15.0 L/min'), findsOneWidget);
      expect(_rmvSemanticsLabel(tester), 'RMV: 15.0 L per minute');
    });

    testWidgets('metric drag stores the dragged L/min value', (tester) async {
      await tester.pumpWidget(_harness(const PlanGasSection()));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanGasSection)),
      );

      tester.widget<Slider>(find.byType(Slider)).onChanged!(20);
      await tester.pumpAndSettle();

      expect(container.read(divePlanNotifierProvider).sacRate, 20);
      expect(find.text('20.0 L/min'), findsOneWidget);
    });

    testWidgets('imperial shows the plan RMV converted to cuft/min', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const PlanGasSection(), settings: _imperialVolume),
      );
      await tester.pumpAndSettle();

      // The default 15 L/min is 0.5297 cuft/min, not "15 cuft/min".
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, closeTo(15 * _cuftPerLiter, 1e-9));
      expect(slider.label, '0.53 cuft/min');
      expect(find.text('0.53 cuft/min'), findsOneWidget);
      expect(find.textContaining('15 cuft'), findsNothing);
      expect(_rmvSemanticsLabel(tester), 'RMV: 0.53 cuft per minute');
    });

    testWidgets('imperial runs 0.30-1.05 cuft/min in 0.05 steps', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const PlanGasSection(), settings: _imperialVolume),
      );
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, closeTo(0.30, 1e-9));
      expect(slider.max, closeTo(1.05, 1e-9));
      expect(slider.divisions, 15);
    });

    testWidgets('imperial drag stores the plan RMV in L/min', (tester) async {
      await tester.pumpWidget(
        _harness(const PlanGasSection(), settings: _imperialVolume),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanGasSection)),
      );

      tester.widget<Slider>(find.byType(Slider)).onChanged!(0.55);
      await tester.pumpAndSettle();

      expect(
        container.read(divePlanNotifierProvider).sacRate,
        closeTo(0.55 / _cuftPerLiter, 1e-6),
      );
      expect(find.text('0.55 cuft/min'), findsOneWidget);
    });

    testWidgets('imperial keeps a plan RMV below the slider floor visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const PlanGasSection(), settings: _imperialVolume),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanGasSection)),
      );

      // 8 L/min is a valid plan RMV, but it is 0.2825 cuft/min, below the
      // 0.30 cuft/min imperial floor. A saved plan can carry it.
      final current = container.read(divePlanNotifierProvider);
      container
          .read(divePlanNotifierProvider.notifier)
          .loadPlan(current.copyWith(sacRate: 8));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, slider.min);
      expect(find.text('0.28 cuft/min'), findsOneWidget);
      expect(container.read(divePlanNotifierProvider).sacRate, 8);
    });
  });

  group('logged RMV hint (#1823)', () {
    testWidgets('metric shows the logged average at 1 decimal', (tester) async {
      await tester.pumpWidget(
        _harness(const PlanGasSection(), loggedRmv: 16.84),
      );
      await tester.pumpAndSettle();

      expect(find.text('Use logged average (16.8 L/min)'), findsOneWidget);
    });

    testWidgets('imperial shows the logged average at 2 decimals', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const PlanGasSection(),
          settings: _imperialVolume,
          loggedRmv: 16.84,
        ),
      );
      await tester.pumpAndSettle();

      // 16.84 L/min is 0.5947 cuft/min; 1 decimal read "0.6".
      expect(find.text('Use logged average (0.59 cuft/min)'), findsOneWidget);
    });

    testWidgets('imperial tap keeps a logged average below the slider floor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const PlanGasSection(),
          settings: _imperialVolume,
          loggedRmv: 8.2,
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanGasSection)),
      );

      await tester.tap(find.text('Use logged average (0.29 cuft/min)'));
      await tester.pumpAndSettle();

      // 8.2 L/min is inside the planner's 8-30 L/min range but below the
      // 0.30 cuft/min imperial floor. The plan takes the value the button
      // named, as it would for a metric diver; only the thumb pins to the
      // floor.
      expect(tester.takeException(), isNull);
      expect(container.read(divePlanNotifierProvider).sacRate, 8.2);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, slider.min);
      expect(find.text('0.29 cuft/min'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsNothing);
    });

    testWidgets('imperial tap on a logged average above 30 L/min hides it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const PlanGasSection(),
          settings: _imperialVolume,
          loggedRmv: 30.3,
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanGasSection)),
      );

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      // The plan clamps to the planner's 30 L/min ceiling, close enough to
      // the logged average that the button hides. Clamping to the snapped
      // 1.05 cuft/min (29.73 L/min) instead left a button that stayed on
      // screen and did nothing when tapped again.
      expect(container.read(divePlanNotifierProvider).sacRate, 30);
      expect(find.byIcon(Icons.history), findsNothing);
    });
  });

  testWidgets('environment section shows altitude group chip at 1000m', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(const PlanEnvironmentSection()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.pumpAndSettle();
    expect(find.textContaining('Group 2'), findsOneWidget);
  });

  testWidgets('environment section water type feeds the plan and deco', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(const PlanEnvironmentSection()));
    await tester.pumpAndSettle();

    expect(find.text('Water type'), findsOneWidget);
    expect(find.text('Salt Water'), findsOneWidget);
    expect(find.text('Standard'), findsNothing);
    expect(find.text('Brackish'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanEnvironmentSection)),
    );
    expect(container.read(divePlanNotifierProvider).waterType, WaterType.salt);

    await tester.tap(find.byType(DropdownButtonFormField<PlannerWaterType>));
    await tester.pumpAndSettle();
    expect(find.text('Standard'), findsNothing);
    expect(find.text('Brackish'), findsNothing);
    expect(find.text('Custom'), findsOneWidget);
    await tester.tap(find.text('Fresh Water').last);
    await tester.pumpAndSettle();

    expect(container.read(divePlanNotifierProvider).waterType, WaterType.fresh);

    await tester.tap(find.byType(DropdownButtonFormField<PlannerWaterType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salt Water').last);
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).waterType, WaterType.salt);
  });

  testWidgets('leftover brackish plans show as custom with an empty salinity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(const PlanEnvironmentSection()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanEnvironmentSection)),
    );
    final current = container.read(divePlanNotifierProvider);
    container
        .read(divePlanNotifierProvider.notifier)
        .loadPlan(current.copyWith(waterType: WaterType.brackish));
    await tester.pumpAndSettle();

    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('Salinity'), findsOneWidget);
    expect(container.read(divePlanNotifierProvider).salinityPpt, isNull);
  });

  testWidgets('custom water type reveals a salinity field', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(const PlanEnvironmentSection()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<PlannerWaterType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();

    expect(find.text('Salinity'), findsOneWidget);
    expect(find.text('ppt'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanEnvironmentSection)),
    );
    expect(container.read(divePlanNotifierProvider).waterType, isNull);
    expect(container.read(divePlanNotifierProvider).salinityPpt, 35.0);

    await tester.enterText(find.byType(TextField).last, '20');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).salinityPpt, 20.0);

    await tester.enterText(find.byType(TextField).last, '');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).salinityPpt, 20.0);

    await tester.enterText(find.byType(TextField).last, 'abc');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).salinityPpt, 20.0);

    await tester.enterText(find.byType(TextField).last, '99');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).salinityPpt, 80.0);

    container.read(divePlanNotifierProvider.notifier).updateSalinityPpt(12);
    await tester.pumpAndSettle();
    expect(find.text('12'), findsWidgets);
  });

  testWidgets('no overflow at narrow widths', (tester) async {
    for (final size in const [Size(300, 600), Size(375, 667)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        _harness(
          const Column(
            children: [
              PlanDecoSection(),
              PlanGasSection(),
              PlanEnvironmentSection(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }
    tester.view.reset();
  });
}
