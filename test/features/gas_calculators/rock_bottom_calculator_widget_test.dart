import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/rock_bottom_calculator.dart';
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
      home: Scaffold(body: RockBottomCalculator()),
    ),
  );
}

const _imperial = AppSettings(
  depthUnit: DepthUnit.feet,
  volumeUnit: VolumeUnit.cubicFeet,
  pressureUnit: PressureUnit.psi,
);

void main() {
  testWidgets('imperial SAC slider offers a selectable cuft/min range', (
    tester,
  ) async {
    await tester.pumpWidget(_host(settings: _imperial));
    await tester.pumpAndSettle();

    // The old build showed "15 cuft/min" as the minimum, which is 425 L/min --
    // roughly 28x a real stressed SAC, so no valid value was selectable.
    expect(find.textContaining('15 cuft/min'), findsNothing);
    expect(find.textContaining('cuft/min'), findsWidgets);
  });

  testWidgets('imperial SAC renders two decimals, not a flattened whole', (
    tester,
  ) async {
    await tester.pumpWidget(_host(settings: _imperial));
    await tester.pumpAndSettle();

    // Defaults are 20 and 25 L/min = 0.71 and 0.88 cuft/min. With the old
    // toStringAsFixed(0) both would render as "1".
    expect(find.textContaining('0.71 cuft/min'), findsOneWidget);
    expect(find.textContaining('0.88 cuft/min'), findsOneWidget);
  });

  testWidgets('imperial ascent rate starts above the old 20 ft/min floor', (
    tester,
  ) async {
    await tester.pumpWidget(_host(settings: _imperial));
    await tester.pumpAndSettle();
    // Default 9 m/min = 29.5 ft/min, snapped to the 5 ft grid.
    expect(find.textContaining('30 ft/min'), findsOneWidget);
  });

  testWidgets('metric build renders a plausible reserve, not near-zero', (
    tester,
  ) async {
    await tester.pumpWidget(_host(settings: const AppSettings()));
    await tester.pumpAndSettle();

    // Case C from the spec: 30 m, 9 m/min, 20+25 L/min, 12 L -> 63.1 bar,
    // rounded up to 70 bar. The old build produced fractions of a bar.
    expect(find.textContaining('70 bar'), findsWidgets);
  });

  testWidgets('shows the planning caveat', (tester) async {
    await tester.pumpWidget(_host(settings: const AppSettings()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Planning estimate'), findsOneWidget);
  });

  testWidgets('shows the problem-solving time input and its gas row', (
    tester,
  ) async {
    await tester.pumpWidget(_host(settings: const AppSettings()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Problem-solving time'), findsOneWidget);
    expect(find.textContaining('Problem-solving gas'), findsOneWidget);
  });

  testWidgets('tank chips show real cylinders in imperial', (tester) async {
    await tester.pumpWidget(_host(settings: _imperial));
    await tester.pumpAndSettle();
    // Rated capacities from TankPresets, not bare water-volume numbers.
    expect(find.textContaining('77'), findsWidgets);
  });
}
