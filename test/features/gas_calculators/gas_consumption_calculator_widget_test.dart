import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_consumption_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host({required AppSettings settings}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
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
    await tester.pumpWidget(_host(settings: const AppSettings()));
    await tester.pumpAndSettle();
    // Default steel 12 L at 200 bar = 2400 L of free gas, not 12 x 200 from a
    // hardcoded constant applied to a mis-stored capacity.
    expect(find.textContaining('2400'), findsWidgets);
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
}
