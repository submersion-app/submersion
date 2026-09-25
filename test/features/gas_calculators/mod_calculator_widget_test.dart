import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/mod_calculator_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod_calculator.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _MemoryRepository extends AppSettingsRepository {
  String? stored;

  @override
  Future<String?> getRawSetting(String key) async => stored;

  @override
  Future<void> setRawSetting(String key, String value) async => stored = value;
}

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
}) async {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsRepositoryProvider.overrideWithValue(_MemoryRepository()),
        settingsProvider.overrideWith((ref) => _FixedSettings(settings)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ModCalculator()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(ModCalculator)));
}

/// Lets the debounced save run out, so no timer outlives the test.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(ModCalculatorNotifier.saveDelay);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Rec shows EAN32 rounded down, with its contingency MOD', (
    tester,
  ) async {
    await _pump(tester);

    // 33.75 m: rounded to nearest this showed 33.8 m.
    expect(find.text('33.7 m'), findsOneWidget);
    expect(find.text('(110 ft)'), findsOneWidget);
    expect(find.text('Contingency MOD at 1.60 bar'), findsOneWidget);
    expect(find.text('40.0m'), findsOneWidget);
    expect(
      find.textContaining('within the recreational limit'),
      findsOneWidget,
    );
    // Rec has no helium, no END and no density.
    expect(find.text('Helium (He)'), findsNothing);
    expect(find.text('END (N₂ + O₂ narcotic)'), findsNothing);
  });

  testWidgets('air in Rec is flagged beyond the recreational limit', (
    tester,
  ) async {
    final container = await _pump(tester);
    container.read(modCalculatorNotifierProvider.notifier).setO2Percent(21);
    await _settle(tester);

    expect(find.text('56.6 m'), findsOneWidget);
    expect(
      find.textContaining('deeper than the recreational limit'),
      findsOneWidget,
    );
  });

  testWidgets('OC Tec adds helium, minimum depth, MND and density', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('OC Tec'));
    await _settle(tester);

    expect(find.text('Helium (He)'), findsOneWidget);
    expect(
      find.textContaining('Minimum depth at ppO₂ 0.18 bar'),
      findsOneWidget,
    );
    expect(find.text('from the surface'), findsOneWidget);
    expect(find.textContaining('MND (END limit'), findsOneWidget);
    expect(find.text('END (N₂ + O₂ narcotic)'), findsOneWidget);
    expect(find.text('Gas density at 0 °C'), findsOneWidget);
    expect(find.text('Open in the gas density calculator'), findsOneWidget);
  });

  testWidgets('CCR Tec names the diluent MOD; the setpoint comes with the '
      'target depth', (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.text('CCR Tec'));
    await _settle(tester);

    expect(find.text('Diluent MOD (flush)'), findsOneWidget);
    expect(find.text('ppO₂ for the diluent MOD (flush)'), findsOneWidget);
    // The setpoint only applies at a target depth: hidden without one.
    expect(find.text('Setpoint (bar)'), findsNothing);

    container
        .read(modCalculatorNotifierProvider.notifier)
        .setCheckTargetDepth(true);
    await _settle(tester);
    expect(find.text('Setpoint (bar)'), findsOneWidget);

    // The flush ppO2 steps by 0.1 bar across 1.0-1.6: six divisions.
    // In CCR Tec it is the only slider over that range.
    final flushSlider = tester.widget<Slider>(
      find.byWidgetPredicate(
        (w) => w is Slider && w.min == 1.0 && w.max == 1.6,
      ),
    );
    expect(flushSlider.divisions, 6);
  });

  testWidgets('a limit moved off the profile value is marked and resettable', (
    tester,
  ) async {
    final container = await _pump(tester);
    expect(find.text('From your diver profile'), findsOneWidget);

    container
        .read(modCalculatorNotifierProvider.notifier)
        .setWorkingPpO2(1.3, profileValue: 1.4);
    await _settle(tester);

    expect(find.text('Differs from your profile (1.40 bar)'), findsOneWidget);
    await tester.tap(find.text('Use profile value'));
    await _settle(tester);
    expect(find.text('From your diver profile'), findsOneWidget);
    expect(container.read(modCalculatorNotifierProvider).workingPpO2, isNull);
  });

  testWidgets('a target deeper than the MOD is a danger', (tester) async {
    final container = await _pump(tester);
    container.read(modCalculatorNotifierProvider.notifier)
      ..setCheckTargetDepth(true)
      ..setTargetDepth(36);
    await _settle(tester);

    expect(find.text('At target depth'), findsOneWidget);
    expect(
      find.textContaining('The target depth is deeper than the MOD'),
      findsOneWidget,
    );
  });

  testWidgets('the mode is kept per calculator state', (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.text('OC Tec'));
    await _settle(tester);
    expect(
      container.read(modCalculatorNotifierProvider).mode,
      ModCalculatorMode.ocTec,
    );
  });

  testWidgets('every mode fits the 400px detail pane without overflow', (
    tester,
  ) async {
    final container = await _pump(tester);
    tester.view.physicalSize = const Size(400, 5000);
    final notifier = container.read(modCalculatorNotifierProvider.notifier)
      ..setCheckTargetDepth(true);
    for (final mode in ModCalculatorMode.values) {
      notifier
        ..setMode(mode)
        ..setCheckTargetDepth(true)
        ..setWorkingPpO2(1.3, profileValue: 1.4)
        ..setFlushPpO2(1.5, profileValue: 1.6);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: mode.name);
    }
  });

  testWidgets('an imperial diver sees feet, rounded down', (tester) async {
    await _pump(tester, settings: const AppSettings(depthUnit: DepthUnit.feet));
    // 33.75 m = 110.73 ft.
    expect(find.text('110.7 ft'), findsOneWidget);
    expect(find.text('(33 m)'), findsOneWidget);
  });
}
