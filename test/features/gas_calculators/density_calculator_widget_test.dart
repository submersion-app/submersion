import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/density_calculator_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/density_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps the calculator and hands back a ref so a test can drive providers.
Future<WidgetRef> _pump(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const DensityCalculator();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('air at 40 m, 0 C, salt water is over the hard ceiling', (
    tester,
  ) async {
    final ref = await _pump(tester);
    ref.read(densityHeProvider.notifier).state = 0;
    ref.read(densityDepthProvider.notifier).state = 40;
    await tester.pumpAndSettle();

    // 6.378 g/L, see gas_density_calculator_test.dart.
    expect(find.text('6.38 g/L'), findsOneWidget);
    expect(
      find.text('Above the 6.2 g/L hard density ceiling.'),
      findsOneWidget,
    );
  });

  testWidgets('20 C and fresh water lower the density', (tester) async {
    final ref = await _pump(tester);
    ref.read(densityHeProvider.notifier).state = 0;
    ref.read(densityDepthProvider.notifier).state = 40;
    await tester.pumpAndSettle();

    await tester.tap(find.text('20°C'));
    await tester.tap(find.text('Fresh Water'));
    await tester.pumpAndSettle();

    expect(ref.read(densityTemperatureProvider), GasDensityTemperature.twentyC);
    expect(ref.read(densityWaterTypeProvider), WaterType.fresh);
    // 5.827 g/L
    expect(find.text('5.83 g/L'), findsOneWidget);
    expect(
      find.text('Above the recommended 5.2 g/L density limit.'),
      findsOneWidget,
    );
  });

  testWidgets('a light trimix is within the recommended limit', (tester) async {
    final ref = await _pump(tester);
    ref.read(densityO2Provider.notifier).state = 18;
    ref.read(densityHeProvider.notifier).state = 45;
    ref.read(densityDepthProvider.notifier).state = 30;
    await tester.pumpAndSettle();

    expect(find.text('Within the recommended 5.2 g/L limit.'), findsOneWidget);
  });

  testWidgets('CCR shows the setpoint and the loop gas', (tester) async {
    final ref = await _pump(tester);
    expect(find.text('Setpoint (bar)'), findsNothing);
    expect(find.text('Loop gas at depth'), findsNothing);

    await tester.tap(find.text('CCR'));
    await tester.pumpAndSettle();

    expect(ref.read(densityCcrProvider), isTrue);
    expect(find.text('Setpoint (bar)'), findsOneWidget);
    expect(find.text('On CCR, the mix above is the diluent.'), findsOneWidget);
    expect(find.text('Loop gas at depth'), findsOneWidget);
  });

  testWidgets('CCR SP 1.3 on 18/45 at 60 m', (tester) async {
    final ref = await _pump(tester);
    ref.read(densityCcrProvider.notifier).state = true;
    ref.read(densityO2Provider.notifier).state = 18;
    ref.read(densityHeProvider.notifier).state = 45;
    ref.read(densityDepthProvider.notifier).state = 60;
    ref.read(densitySetpointProvider.notifier).state = 1.3;
    await tester.pumpAndSettle();

    // 5.576 g/L at 0 C
    expect(find.text('5.58 g/L'), findsOneWidget);
    // pO2 1.3 / 7.031 = 18.5 %, pHe 3.145 / 7.031 = 44.7 %,
    // pN2 2.586 / 7.031 = 36.8 %
    expect(find.text('O2 18.5 % · He 44.7 % · N2 36.8 %'), findsOneWidget);
  });

  testWidgets('CCR explains a diluent richer than the setpoint', (
    tester,
  ) async {
    final ref = await _pump(tester);
    ref.read(densityCcrProvider.notifier).state = true;
    ref.read(densityHeProvider.notifier).state = 0;
    ref.read(densityDepthProvider.notifier).state = 60;
    await tester.pumpAndSettle();

    expect(find.textContaining('The diluent alone gives ppO2 1.48'), findsOne);
  });

  testWidgets('CCR at the surface explains the pure oxygen loop', (
    tester,
  ) async {
    final ref = await _pump(tester);
    ref.read(densityCcrProvider.notifier).state = true;
    ref.read(densityDepthProvider.notifier).state = 0;
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The setpoint is above ambient pressure here, so the loop is pure '
        'oxygen.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the info card states the limits from the constants', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      find.textContaining('at or below 5.2 g/L; 6.2 g/L is the hard ceiling'),
      findsOneWidget,
    );
  });

  testWidgets('the depth slider steps in whole feet', (tester) async {
    final ref = await _pump(
      tester,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );

    final depthSlider = tester.widget<Slider>(find.byType(Slider).at(2));
    expect(depthSlider.max, 500);
    expect(depthSlider.divisions, 500);

    depthSlider.onChanged!(100);
    await tester.pumpAndSettle();
    expect(ref.read(densityDepthProvider), closeTo(100 / 3.28084, 1e-3));
    expect(find.text('100ft'), findsOneWidget);
  });

  testWidgets('sliders announce the displayed value', (tester) async {
    await _pump(tester);
    final depthSlider = tester.widget<Slider>(find.byType(Slider).at(2));
    expect(depthSlider.semanticFormatterCallback!(50), '50m');
  });

  testWidgets('imperial settings show feet and Fahrenheit', (tester) async {
    await _pump(
      tester,
      settings: const AppSettings(
        depthUnit: DepthUnit.feet,
        temperatureUnit: TemperatureUnit.fahrenheit,
      ),
    );

    // Default depth 50 m = 164 ft.
    expect(find.text('164ft'), findsOneWidget);
    expect(find.text('32°F'), findsOneWidget);
    expect(find.text('68°F'), findsOneWidget);
  });

  testWidgets('lowering O2 below the helium room clamps helium', (
    tester,
  ) async {
    final ref = await _pump(tester);
    ref.read(densityHeProvider.notifier).state = 70;
    await tester.pumpAndSettle();

    // Drag the O2 slider to its maximum: helium must follow down to 0.
    final o2Slider = find.byType(Slider).first;
    await tester.drag(o2Slider, const Offset(2000, 0));
    await tester.pumpAndSettle();

    expect(ref.read(densityO2Provider), 100);
    expect(ref.read(densityHeProvider), 0);
  });
}
