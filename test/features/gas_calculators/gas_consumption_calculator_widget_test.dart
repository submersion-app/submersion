import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_calculators_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_consumption_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host({
  required AppSettings settings,
  double? depthMeters,
  int? minutes,
  double? sacLpm,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
      if (depthMeters != null)
        consumptionDepthProvider.overrideWith((ref) => depthMeters),
      if (minutes != null)
        consumptionTimeProvider.overrideWith((ref) => minutes),
      if (sacLpm != null) consumptionSacProvider.overrideWith((ref) => sacLpm),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: GasConsumptionCalculator()),
    ),
  );
}

const _imperial = AppSettings(
  depthUnit: DepthUnit.feet,
  volumeUnit: VolumeUnit.cubicFeet,
  pressureUnit: PressureUnit.psi,
);

void main() {
  testWidgets('imperial SAC slider is on a cuft/min scale', (tester) async {
    await tester.pumpWidget(_host(settings: _imperial));
    await tester.pumpAndSettle();
    // The old slider ran 8-30 "cuft/min", i.e. 226-850 L/min.
    expect(find.textContaining('8 cuft/min'), findsNothing);
    // Default 15 L/min = 0.53 cuft/min, needing two decimals to render.
    expect(find.textContaining('0.53 cuft/min'), findsOneWidget);
  });

  testWidgets('shows the planning caveat', (tester) async {
    await tester.pumpWidget(_host(settings: const AppSettings()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Planning estimate'), findsOneWidget);
  });

  testWidgets('metric tank capacity reflects the cylinder working pressure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(settings: const AppSettings(gasModel: GasModel.ideal)),
    );
    await tester.pumpAndSettle();
    // Default steel 12 L at 200 bar = 2400 L of free gas, not 12 x 200 from a
    // hardcoded constant applied to a mis-stored capacity.
    expect(find.textContaining('2400'), findsWidgets);
  });

  testWidgets('tank capacity honors the gas model preference', (tester) async {
    // The same cylinder reads lower once compressibility is applied, which is
    // the whole point of the preference (issue #828).
    await tester.pumpWidget(
      _host(settings: const AppSettings(gasModel: GasModel.real)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('2317'), findsWidgets);
    expect(find.textContaining('2400'), findsNothing);
  });

  testWidgets('renders a metric consumption result in bar', (tester) async {
    await tester.pumpWidget(_host(settings: const AppSettings()));
    await tester.pumpAndSettle();
    expect(find.text('bar'), findsWidgets);
  });

  testWidgets('renders an imperial consumption result in psi', (tester) async {
    await tester.pumpWidget(_host(settings: _imperial));
    await tester.pumpAndSettle();
    expect(find.text('psi'), findsWidgets);
  });

  testWidgets('a plan that overruns the cylinder shows no negative remaining', (
    tester,
  ) async {
    // 25 L/min at 40 m for 90 min wants 11250 L from a 12 L cylinder that
    // holds ~2317. The card already turns red and says the plan exceeds
    // capacity; showing "-8933 L (-744 bar) remaining" on top of that is
    // nonsense, so the remaining figures floor at zero.
    await tester.pumpWidget(
      _host(
        settings: const AppSettings(),
        depthMeters: 40.0,
        minutes: 90,
        sacLpm: 25.0,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('-'), findsNothing);
    expect(find.textContaining('0 L (0 bar)'), findsOneWidget);
  });
}
