import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_conditions_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<WidgetRef> _pump(WidgetTester tester, {AppSettings? settings}) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(settings ?? const AppSettings()),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, _) {
                captured = ref;
                return const BlenderConditionsCard();
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('offers the Celsius ladder', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('blender-fill-temp')));
    await tester.pumpAndSettle();
    for (final v in ['0 °C', '5 °C', '20 °C', '35 °C']) {
      expect(find.text(v), findsWidgets);
    }
  });

  testWidgets('offers the Fahrenheit ladder', (tester) async {
    await _pump(
      tester,
      settings: const AppSettings(temperatureUnit: TemperatureUnit.fahrenheit),
    );
    await tester.tap(find.byKey(const Key('blender-fill-temp')));
    await tester.pumpAndSettle();
    for (final v in ['30 °F', '70 °F', '100 °F']) {
      expect(find.text(v), findsWidgets);
    }
  });

  testWidgets('choosing a fill temperature writes Celsius', (tester) async {
    final ref = await _pump(tester);
    await tester.tap(find.byKey(const Key('blender-fill-temp')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 °C').last);
    await tester.pumpAndSettle();
    expect(ref.read(blenderFillTempProvider), 5);
  });

  testWidgets('choosing a gas model writes the provider', (tester) async {
    final ref = await _pump(tester);
    await tester.tap(find.byKey(const Key('blender-gas-model')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ideal gas').last);
    await tester.pumpAndSettle();
    expect(ref.read(blenderGasModelProvider), BlendGasModel.ideal);
  });

  testWidgets('marks the Z-factor model as recommended', (tester) async {
    await _pump(tester);
    expect(find.textContaining('Recommended'), findsOneWidget);
  });
  testWidgets('the dropdowns follow a programmatic change', (tester) async {
    // Raised in review on PR #1215 against an older Flutter API, where the
    // controlled property was `value`. In this version `value` is deprecated
    // and `initialValue` is its replacement, and it does track. This test is
    // the proof, so a future refactor cannot quietly break the preference load.
    final ref = await _pump(tester);
    expect(find.text('20 °C'), findsNWidgets(2));

    ref.read(blenderGasModelProvider.notifier).state = BlendGasModel.ideal;
    ref.read(blenderFillTempProvider.notifier).state = 5;
    await tester.pumpAndSettle();

    expect(find.text('Ideal gas'), findsOneWidget);
    expect(find.text('5 °C'), findsOneWidget);
    expect(find.text('20 °C'), findsOneWidget);
  });
}
