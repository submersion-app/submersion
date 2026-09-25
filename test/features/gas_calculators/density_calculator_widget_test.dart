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
  Size size = const Size(900, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
      ],
      child: MaterialApp(
        // The assertions read English text; pin it rather than rely on the
        // test binding's default locale.
        locale: const Locale('en'),
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

  testWidgets('shows the equivalent air density depth', (tester) async {
    final ref = await _pump(tester);
    ref.read(densityO2Provider.notifier).state = 18;
    ref.read(densityHeProvider.notifier).state = 45;
    ref.read(densityDepthProvider.notifier).state = 60;
    await tester.pumpAndSettle();

    // 33.5 m, see gas_density_calculator_test.dart.
    expect(
      find.text('Equivalent air density depth (EADD): 34m'),
      findsOneWidget,
    );
  });

  testWidgets('shows the EADD in feet for imperial settings', (tester) async {
    final ref = await _pump(
      tester,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );
    ref.read(densityHeProvider.notifier).state = 0;
    ref.read(densityDepthProvider.notifier).state = 40;
    await tester.pumpAndSettle();

    // Air is its own EADD: 40 m = 131 ft.
    expect(
      find.text('Equivalent air density depth (EADD): 131ft'),
      findsOneWidget,
    );
  });

  testWidgets('temperature and water type sit side by side when wide', (
    tester,
  ) async {
    await _pump(tester);
    final temperature = tester.getTopLeft(find.text('Gas temperature'));
    final water = tester.getTopLeft(find.text('Water type'));
    expect(water.dy, temperature.dy);
    expect(water.dx, greaterThan(temperature.dx));
  });

  testWidgets('temperature and water type stack on a narrow screen', (
    tester,
  ) async {
    await _pump(tester, size: const Size(360, 2400));
    final temperature = tester.getTopLeft(find.text('Gas temperature'));
    final water = tester.getTopLeft(find.text('Water type'));
    expect(water.dy, greaterThan(temperature.dy));
    expect(tester.takeException(), isNull);
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

  testWidgets('the depth slider steps in 5 ft within the 150 m range', (
    tester,
  ) async {
    final ref = await _pump(
      tester,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );

    // 150 m = 492.1 ft, floored to the 5 ft grid.
    final depthSlider = tester.widget<Slider>(find.byType(Slider).at(2));
    expect(depthSlider.max, 490);
    expect(depthSlider.divisions, 98);

    depthSlider.onChanged!(100);
    await tester.pumpAndSettle();
    expect(ref.read(densityDepthProvider), closeTo(100 / 3.28084, 1e-3));
    expect(find.text('100 ft'), findsOneWidget);
  });

  testWidgets('the metric depth slider steps in 1 m up to 150 m', (
    tester,
  ) async {
    await _pump(tester);
    final depthSlider = tester.widget<Slider>(find.byType(Slider).at(2));
    expect(depthSlider.max, 150);
    expect(depthSlider.divisions, 150);
    expect(find.text('50 m'), findsOneWidget);
  });

  testWidgets('sliders announce the displayed value', (tester) async {
    await _pump(tester);
    final o2Slider = tester.widget<Slider>(find.byType(Slider).first);
    expect(o2Slider.semanticFormatterCallback!(21), '21%');
  });

  testWidgets('screen readers reach the CCR hints', (tester) async {
    final handle = tester.ensureSemantics();
    final ref = await _pump(tester);
    ref.read(densityCcrProvider.notifier).state = true;
    ref.read(densityDepthProvider.notifier).state = 0;
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('loop is pure oxygen')), findsOne);
    expect(find.bySemanticsLabel(RegExp('O2 100.0 % · He 0.0 %')), findsOne);
    handle.dispose();
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
    expect(find.text('164 ft'), findsOneWidget);
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
