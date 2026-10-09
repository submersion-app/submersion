import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix.dart'
    show BestMixMode, CcrGasSource;
import 'package:submersion/features/gas_calculators/presentation/providers/best_mix_calculator_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix_calculator.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

class _MemoryRepository extends AppSettingsRepository {
  String? stored;

  @override
  Future<String?> getRawSetting(String key) async => stored;

  @override
  Future<void> setRawSetting(String key, String value) async => stored = value;
}

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
        appSettingsRepositoryProvider.overrideWithValue(_MemoryRepository()),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
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

/// Lets the debounced save run out, so no timer outlives the test.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(BestMixCalculatorNotifier.saveDelay);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('at 111 ft the recommendation is never EAN32', (tester) async {
    final ref = await _pump(
      tester,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );

    ref
        .read(bestMixCalculatorNotifierProvider.notifier)
        .setDepth(111 / 3.28084);
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
    await _settle(tester);
  });

  testWidgets('shows the recommended mix MOD and margin', (tester) async {
    await _pump(tester);
    expect(find.textContaining('MOD'), findsWidgets);
    expect(find.textContaining('Margin'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('shows END and gas density for the recommendation', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.textContaining('END at depth'), findsWidgets);
    expect(find.textContaining('g/L'), findsWidgets);
    await _settle(tester);
  });

  testWidgets('offers the helium-free alternative when helium was added', (
    tester,
  ) async {
    final ref = await _pump(tester);
    ref.read(bestMixCalculatorNotifierProvider.notifier).setDepth(50);
    await tester.pumpAndSettle();

    expect(find.textContaining('Without helium'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('hides the alternative when no helium was needed', (
    tester,
  ) async {
    final ref = await _pump(tester);
    ref.read(bestMixCalculatorNotifierProvider.notifier).setDepth(20);
    await tester.pumpAndSettle();

    expect(find.textContaining('Without helium'), findsNothing);
    await _settle(tester);
  });

  testWidgets('shows the planning caveat', (tester) async {
    await _pump(tester);
    expect(find.textContaining('Planning estimate'), findsOneWidget);
    await _settle(tester);
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
    await _settle(tester);
  });

  testWidgets('OC-Tec shows EAD alongside END, and no density card in Rec', (
    tester,
  ) async {
    final ref = await _pump(tester);
    expect(find.textContaining('EAD at depth'), findsNothing);

    ref
        .read(bestMixCalculatorNotifierProvider.notifier)
        .setMode(BestMixMode.ocTec);
    await tester.pumpAndSettle();

    // EAD is shown once, on the recommendation; the alternative card (also
    // visible here, since this depth needs helium) keeps END-only, same as
    // Rec always has.
    expect(find.textContaining('EAD at depth'), findsOneWidget);
    expect(find.textContaining('END at depth'), findsWidgets);
    expect(find.text('Keep gas density within limits'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('CCR-Tec offers a Diluent/Bailout source choice', (tester) async {
    final ref = await _pump(tester);
    ref
        .read(bestMixCalculatorNotifierProvider.notifier)
        .setMode(BestMixMode.ccrTec);
    await tester.pumpAndSettle();

    expect(find.text('Diluent'), findsOneWidget);
    expect(find.text('Bailout'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('OC-Tec shows an editable ppO2 slider, not a static value', (
    tester,
  ) async {
    final ref = await _pump(tester);
    final notifier = ref.read(bestMixCalculatorNotifierProvider.notifier)
      ..setMode(BestMixMode.ocTec);
    await tester.pumpAndSettle();

    expect(find.text('Working ppO₂'), findsOneWidget);
    // Three profile-backed controls in OC-Tec: working ppO2, END limit, and
    // O2-narcotic, all unmoved from the profile at this point.
    expect(find.text('From your diver profile'), findsNWidgets(3));

    notifier.setWorkingPpO2(1.2);
    await tester.pumpAndSettle();

    expect(find.textContaining('Differs from your profile'), findsOneWidget);
    expect(find.text('Use profile value'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('OC-Tec offers an END limit slider, overridable per diver', (
    tester,
  ) async {
    final ref = await _pump(tester);
    final notifier = ref.read(bestMixCalculatorNotifierProvider.notifier)
      ..setMode(BestMixMode.ocTec);
    await tester.pumpAndSettle();

    expect(find.text('END Limit'), findsOneWidget);

    notifier.setEndLimit(25);
    await tester.pumpAndSettle();

    expect(find.textContaining('Differs from your profile'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('OC-Tec lets the diver override whether O2 counts as narcotic', (
    tester,
  ) async {
    final ref = await _pump(tester);
    final notifier = ref.read(bestMixCalculatorNotifierProvider.notifier)
      ..setMode(BestMixMode.ocTec);
    await tester.pumpAndSettle();

    expect(find.text('O2 is narcotic'), findsOneWidget);

    notifier.setO2Narcotic(false);
    await tester.pumpAndSettle();

    expect(find.textContaining('Differs from your profile'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('CCR-Tec Diluent shows the diluent flush ppO2 slider', (
    tester,
  ) async {
    final ref = await _pump(tester);
    ref
        .read(bestMixCalculatorNotifierProvider.notifier)
        .setMode(BestMixMode.ccrTec);
    await tester.pumpAndSettle();

    expect(find.text('ppO₂ for the diluent MOD (flush)'), findsOneWidget);
    expect(find.text('Working ppO₂'), findsNothing);
    await _settle(tester);
  });

  testWidgets('CCR-Tec Bailout shows the working ppO2 slider, same as OC-Tec', (
    tester,
  ) async {
    final ref = await _pump(tester);
    ref.read(bestMixCalculatorNotifierProvider.notifier)
      ..setMode(BestMixMode.ccrTec)
      ..setCcrSource(CcrGasSource.bailout);
    await tester.pumpAndSettle();

    expect(find.text('Working ppO₂'), findsOneWidget);
    expect(find.text('ppO₂ for the diluent MOD (flush)'), findsNothing);
    await _settle(tester);
  });
}
