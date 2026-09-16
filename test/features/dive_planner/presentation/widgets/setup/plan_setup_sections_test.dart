import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_deco_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_environment_section.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
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

/// The planner number-box row labelled [label] ("Bottom RMV", "GF Low").
Finder _planRow(String label) => find.widgetWithText(PlanNumberField, label);

/// The text field inside the number-box row labelled [label].
Finder _planField(String label) =>
    find.descendant(of: _planRow(label), matching: find.byType(TextField));

String _planFieldText(WidgetTester tester, String label) =>
    tester.widget<TextField>(_planField(label)).controller!.text;

String? _planFieldHint(WidgetTester tester, String label) =>
    tester.widget<TextField>(_planField(label)).decoration!.hintText;

/// The Semantics label wrapping the Bottom RMV field.
String? _rmvSemanticsLabel(WidgetTester tester) => tester
    .widgetList<Semantics>(
      find.ancestor(
        of: _planField('Bottom RMV'),
        matching: find.byType(Semantics),
      ),
    )
    .map((s) => s.properties.label)
    .firstWhere((label) => label?.startsWith('RMV') ?? false);

void main() {
  // MaterialApp's locale does not reach the number formatting: formatRmv
  // localises its decimal separator from the process-global
  // Intl.defaultLocale. Pin English so "0.53 cuft/min" stays dot-separated.
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

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

  testWidgets('deco section renders both GF boxes at the diver settings', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanDecoSection()));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(PlanNumberField), findsNWidgets(2));
    // AppSettings defaults: GF 50/85.
    expect(_planFieldText(tester, 'GF Low'), '50');
    expect(_planFieldText(tester, 'GF High'), '85');
    expect(find.text('%'), findsNWidgets(2));
  });

  testWidgets('typing in the GF Low box changes gfLow and leaves gfHigh', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanDecoSection()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanDecoSection)),
    );
    expect(container.read(divePlanNotifierProvider).gfLow, 50);
    expect(container.read(divePlanNotifierProvider).gfHigh, 85);

    await tester.enterText(_planField('GF Low'), '35');
    await tester.pumpAndSettle();

    final state = container.read(divePlanNotifierProvider);
    expect(state.gfLow, 35);
    expect(state.gfHigh, 85);
  });

  testWidgets('typing in the GF High box changes gfHigh and leaves gfLow', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanDecoSection()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanDecoSection)),
    );

    await tester.enterText(_planField('GF High'), '70');
    await tester.pumpAndSettle();

    final state = container.read(divePlanNotifierProvider);
    expect(state.gfHigh, 70);
    expect(state.gfLow, 50);
  });

  testWidgets('GF boxes refuse a value outside the 10-100% band', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanDecoSection()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanDecoSection)),
    );

    // A gradient factor over 100 is not a conservative plan, it is nonsense:
    // the box flags it and the plan keeps the last good value.
    await tester.enterText(_planField('GF High'), '120');
    await tester.pumpAndSettle();

    expect(container.read(divePlanNotifierProvider).gfHigh, 85);
    expect(
      tester.widget<TextField>(_planField('GF High')).decoration?.errorText,
      isNotNull,
    );
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

  testWidgets('gas section shows RMV field and reserve field with unit', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanGasSection()));
    await tester.pumpAndSettle();
    expect(find.text('Bottom RMV'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('50'), findsOneWidget);
    expect(find.textContaining('bar'), findsWidgets);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGasSection)),
    );
    await tester.enterText(find.byType(TextField).first, '20');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).sacRate, 20);
  });

  testWidgets('reserve validation: zero shows error, valid updates state', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const PlanGasSection()));
    await tester.pumpAndSettle();
    // The reserve field sits above the gas options block, so find it by its
    // semantics label rather than by position.
    final field = find.descendant(
      of: find.bySemanticsLabel(RegExp('Reserve pressure')),
      matching: find.byType(TextField),
    );
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

  group('Bottom RMV field units (#1823)', () {
    testWidgets('metric shows the plan RMV in L/min', (tester) async {
      await tester.pumpWidget(_harness(const PlanGasSection()));
      await tester.pumpAndSettle();

      expect(_planFieldText(tester, 'Bottom RMV'), '15');
      expect(
        find.descendant(
          of: _planRow('Bottom RMV'),
          matching: find.text('L/min'),
        ),
        findsOneWidget,
      );
      expect(_rmvSemanticsLabel(tester), 'RMV: 15.0 L per minute');
    });

    testWidgets('metric entry keeps one decimal and stores L/min', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const PlanGasSection()));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanGasSection)),
      );

      await tester.enterText(_planField('Bottom RMV'), '17.5');
      await tester.pumpAndSettle();

      expect(container.read(divePlanNotifierProvider).sacRate, 17.5);
      expect(_planFieldText(tester, 'Bottom RMV'), '17.5');
    });

    testWidgets('imperial shows the plan RMV converted to cuft/min', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const PlanGasSection(), settings: _imperialVolume),
      );
      await tester.pumpAndSettle();

      // The default 15 L/min is 0.5297 cuft/min, not "15 cuft/min", and at
      // 1 decimal it read "0.5".
      expect(_planFieldText(tester, 'Bottom RMV'), '0.53');
      expect(
        find.descendant(
          of: _planRow('Bottom RMV'),
          matching: find.text('cuft/min'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('15 cuft'), findsNothing);
      expect(_rmvSemanticsLabel(tester), 'RMV: 0.53 cuft per minute');
    });

    testWidgets('imperial entry keeps two decimals and stores L/min', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const PlanGasSection(), settings: _imperialVolume),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanGasSection)),
      );

      await tester.enterText(_planField('Bottom RMV'), '0.55');
      await tester.pumpAndSettle();

      expect(
        container.read(divePlanNotifierProvider).sacRate,
        closeTo(0.55 / _cuftPerLiter, 1e-6),
      );
      // The field re-seeds from the plan after every edit; at 1 decimal it
      // rewrote the diver's "0.55" to "0.6" mid-entry.
      expect(_planFieldText(tester, 'Bottom RMV'), '0.55');
    });

    testWidgets('imperial re-seeds the field when the plan RMV changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const PlanGasSection(), settings: _imperialVolume),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanGasSection)),
      );

      // 8 L/min is 0.2825 cuft/min, which 1 decimal rounded to "0.3".
      final current = container.read(divePlanNotifierProvider);
      container
          .read(divePlanNotifierProvider.notifier)
          .loadPlan(current.copyWith(sacRate: 8));
      await tester.pumpAndSettle();

      expect(_planFieldText(tester, 'Bottom RMV'), '0.28');
      expect(_rmvSemanticsLabel(tester), 'RMV: 0.28 cuft per minute');
      expect(container.read(divePlanNotifierProvider).sacRate, 8);
    });
  });

  group('Deco RMV field units (#1823)', () {
    testWidgets('metric hints and stores L/min', (tester) async {
      await tester.pumpWidget(_harness(const PlanGasSection()));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanGasSection)),
      );

      expect(_planFieldHint(tester, 'Deco RMV'), '15');

      await tester.enterText(_planField('Deco RMV'), '12.5');
      await tester.pumpAndSettle();

      expect(container.read(divePlanNotifierProvider).sacDeco, 12.5);
      expect(_planFieldText(tester, 'Deco RMV'), '12.5');
    });

    testWidgets('imperial hints and edits at two decimals', (tester) async {
      await tester.pumpWidget(
        _harness(const PlanGasSection(), settings: _imperialVolume),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanGasSection)),
      );

      expect(_planFieldHint(tester, 'Deco RMV'), '0.53');

      await tester.enterText(_planField('Deco RMV'), '0.45');
      await tester.pumpAndSettle();

      expect(
        container.read(divePlanNotifierProvider).sacDeco,
        closeTo(0.45 / _cuftPerLiter, 1e-6),
      );
      expect(_planFieldText(tester, 'Deco RMV'), '0.45');
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

    testWidgets('imperial tap applies a logged average below 0.30 cuft/min', (
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
      // 0.30 cuft/min floor of the calculator's imperial RMV axis. The plan
      // takes the value the button named, as it would for a metric diver.
      expect(tester.takeException(), isNull);
      expect(container.read(divePlanNotifierProvider).sacRate, 8.2);
      expect(_planFieldText(tester, 'Bottom RMV'), '0.29');
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
