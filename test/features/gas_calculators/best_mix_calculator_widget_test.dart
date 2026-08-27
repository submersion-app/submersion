import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_calculators_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix_calculator.dart';
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
              return const BestMixCalculator();
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
  testWidgets('at 111 ft the recommendation is never EAN32', (tester) async {
    final ref = await _pump(
      tester,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );

    ref.read(bestMixDepthProvider.notifier).state = 111 / 3.28084;
    await tester.pumpAndSettle();

    // EAN32's own MOD at ppO2 1.4 is 110.7 ft -- shallower than the dive.
    // Oxygen must floor to 31, which at this depth also carries helium
    // because EAN31's END of 111 ft busts the 30 m limit.
    //
    // Asserted positively on the recommendation rather than by the absence of
    // "EAN32": the common-mixes reference table further down legitimately
    // lists EAN32 alongside its MOD, and should keep doing so.
    expect(find.text('Tx 31/10'), findsOneWidget);

    // The helium-free fallback is EAN31, never the rounded-up EAN32.
    expect(find.text('EAN31'), findsOneWidget);
  });

  testWidgets('shows the recommended mix MOD and margin', (tester) async {
    await _pump(tester);
    expect(find.textContaining('MOD'), findsWidgets);
    expect(find.textContaining('Margin'), findsOneWidget);
  });

  testWidgets('shows END and gas density for the recommendation', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.textContaining('END at depth'), findsWidgets);
    expect(find.textContaining('g/L'), findsWidgets);
  });

  testWidgets('offers the helium-free alternative when helium was added', (
    tester,
  ) async {
    final ref = await _pump(tester);
    ref.read(bestMixDepthProvider.notifier).state = 50;
    await tester.pumpAndSettle();

    expect(find.textContaining('Without helium'), findsOneWidget);
  });

  testWidgets('hides the alternative when no helium was needed', (
    tester,
  ) async {
    final ref = await _pump(tester);
    ref.read(bestMixDepthProvider.notifier).state = 20;
    await tester.pumpAndSettle();

    expect(find.textContaining('Without helium'), findsNothing);
  });

  testWidgets('shows the planning caveat', (tester) async {
    await _pump(tester);
    expect(find.textContaining('Planning estimate'), findsOneWidget);
  });

  testWidgets('ppO2 stays in bar even for an imperial diver', (tester) async {
    await _pump(
      tester,
      settings: const AppSettings(
        depthUnit: DepthUnit.feet,
        pressureUnit: PressureUnit.psi,
      ),
    );
    // ppO2 is a physics unit; converting it to psi would be wrong.
    expect(find.textContaining('1.4 bar'), findsOneWidget);
  });
}
