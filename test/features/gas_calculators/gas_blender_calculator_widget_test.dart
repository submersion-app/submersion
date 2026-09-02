import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/presentation/providers/gas_calculators_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  /// Lets a test change units mid-session the way the settings page would.
  void apply(AppSettings next) => state = next;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Re-created by every [_pump] so a unit change in one test cannot leak into
/// the next.
late _TestSettingsNotifier _settings;

Future<WidgetRef> _pump(WidgetTester tester) async {
  _settings = _TestSettingsNotifier(const AppSettings());
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsProvider.overrideWith((ref) => _settings)],
      child: MaterialApp(
        // flutter_test forwards the host machine's locale list, so an unpinned
        // MaterialApp renders translated on a non-English dev machine and every
        // English finder below misses.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const GasBlenderCalculator();
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
  testWidgets('default nitrox target shows the EAN32 fill procedure', (
    tester,
  ) async {
    await _pump(tester);

    // Procedure heading and the target nitrox both render.
    expect(find.text('Fill procedure'), findsOneWidget);
    expect(find.textContaining('EAN32'), findsWidgets);
  });

  testWidgets('a target pressure below the start shows an error', (
    tester,
  ) async {
    final ref = await _pump(tester);

    ref.read(blenderStartPressureProvider.notifier).state = 250;
    await tester.pumpAndSettle();

    expect(find.textContaining('higher than the starting'), findsOneWidget);
    expect(find.text('Fill procedure'), findsNothing);
  });

  testWidgets('a trimix target produces a Tx fill procedure', (tester) async {
    final ref = await _pump(tester);

    ref.read(blenderTargetMixProvider.notifier).state = const GasMix(
      o2: 18,
      he: 45,
    );
    await tester.pumpAndSettle();

    expect(find.text('Fill procedure'), findsOneWidget);
    expect(find.textContaining('Tx 18/45'), findsWidgets);
  });

  testWidgets('the default fill order tops off with air, not helium', (
    tester,
  ) async {
    final ref = await _pump(tester);

    expect(ref.read(blenderFillGas1Provider), const GasMix(o2: 100));
    expect(ref.read(blenderFillGas2Provider), const GasMix(o2: 0, he: 100));
    expect(ref.read(blenderFillGas3Provider), const GasMix(o2: 21));
  });

  testWidgets('a nitrox target skips the helium source in the defaults', (
    tester,
  ) async {
    await _pump(tester);

    // Defaults are an empty cylinder to EAN32: O2 then air, no helium step.
    // Scoped to the procedure card: the costing card names every configured
    // bank, helium included, because a price belongs to the bank rather than
    // to this particular fill.
    expect(find.text('Add Air'), findsOneWidget);
    expect(find.text('Add Helium'), findsNothing);
  });

  testWidgets('renders English even on a non-English host machine', (
    tester,
  ) async {
    // flutter_test forwards the host's locale list; without a pinned locale
    // the app resolves to one of its eleven translations and every English
    // finder in this file silently misses.
    tester.platformDispatcher.localesTestValue = const [
      Locale('fr'),
      Locale('en'),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await _pump(tester);

    expect(find.text('Fill procedure'), findsOneWidget);
  });

  testWidgets('switching to psi re-seeds the pressure fields', (tester) async {
    await _pump(tester);

    expect(find.widgetWithText(TextField, '200'), findsOneWidget);

    _settings.apply(const AppSettings(pressureUnit: PressureUnit.psi));
    await tester.pumpAndSettle();

    // 200 bar is 2901 psi. Leaving "200" on screen would relabel the target as
    // 200 psi, a seventh of the fill the diver asked for.
    expect(find.widgetWithText(TextField, '200'), findsNothing);
    expect(find.widgetWithText(TextField, '2901'), findsOneWidget);
  });

  testWidgets('an over-rich cylinder is told what to drain to', (tester) async {
    final ref = await _pump(tester);

    ref.read(blenderStartPressureProvider.notifier).state = 150;
    ref.read(blenderStartMixProvider.notifier).state = const GasMix(o2: 40);
    ref.read(blenderTargetMixProvider.notifier).state = const GasMix(o2: 28);
    await tester.pumpAndSettle();

    expect(find.textContaining('Drain to'), findsOneWidget);
    expect(find.text('Fill procedure'), findsNothing);
  });
  testWidgets('a fractional pressure survives a unit change', (tester) async {
    final ref = await _pump(tester);

    await tester.enterText(
      find
          .byWidgetPredicate(
            (w) =>
                w is TextField &&
                (w.decoration?.labelText ?? '').startsWith('Pressure'),
          )
          .first,
      '207.6',
    );
    await tester.pumpAndSettle();
    expect(ref.read(blenderStartPressureProvider), closeTo(207.6, 0.001));

    _settings.apply(const AppSettings(pressureUnit: PressureUnit.psi));
    await tester.pumpAndSettle();
    _settings.apply(const AppSettings());
    await tester.pumpAndSettle();

    expect(ref.read(blenderStartPressureProvider), closeTo(207.6, 0.05));
    expect(find.widgetWithText(TextField, '208'), findsNothing);
  });

  testWidgets('a fractional trimix is labelled without rounding', (
    tester,
  ) async {
    final ref = await _pump(tester);
    ref.read(blenderStartMixProvider.notifier).state = const GasMix(
      o2: 8.3,
      he: 73.4,
    );
    ref.read(blenderTargetMixProvider.notifier).state = const GasMix(
      o2: 8.3,
      he: 73.4,
    );
    ref.read(blenderStartPressureProvider.notifier).state = 80;
    ref.read(blenderTargetPressureProvider.notifier).state = 220;
    await tester.pumpAndSettle();

    expect(find.textContaining('Tx 8.3/73.4'), findsWidgets);
    expect(find.textContaining('Tx 8/73'), findsNothing);
  });

  testWidgets('a narrow surface does not overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester);
    expect(tester.takeException(), isNull);
  });
  testWidgets('each fill step shows the bar delivered', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderTargetMixProvider.notifier).state = const GasMix(
      o2: 18,
      he: 45,
    );
    await tester.pumpAndSettle();

    // The procedure card and the costing card both name the bar delivered:
    // one so the blender knows when to stop, one so the bill reconciles.
    expect(find.textContaining('+15.3'), findsWidgets);
    expect(find.textContaining('104.3'), findsOneWidget);
  });

  testWidgets('a chilled fill names the settled pressure', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderFillTempProvider.notifier).state = 5;
    await tester.pumpAndSettle();

    expect(find.textContaining('Settles to'), findsOneWidget);
    expect(find.textContaining('200.0'), findsWidgets);
  });

  testWidgets('an equal-temperature fill does not claim a settle', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.textContaining('Settles to'), findsNothing);
  });

  testWidgets('the litres summary line is gone', (tester) async {
    await _pump(tester);
    expect(find.text('Gas to add'), findsNothing);
  });
  testWidgets('clearing a mix box does not silently mean zero', (tester) async {
    // Reported on PR #1215. Clearing O2 and He before typing a replacement
    // left the blender solving for 0% O2 and 0% He, i.e. pure nitrogen, and it
    // answered with a well-formed fill procedure for a cylinder nobody has.
    // Only a cross-check against three other blending tools caught it.
    final ref = await _pump(tester);
    final fields = find.byType(TextField);

    await tester.enterText(fields.at(0), '40');
    await tester.enterText(fields.at(1), '14.5');
    await tester.enterText(fields.at(2), '57.2');
    await tester.pumpAndSettle();
    expect(ref.read(blenderStartMixProvider).o2, closeTo(14.5, 0.001));

    await tester.enterText(fields.at(1), '');
    await tester.enterText(fields.at(2), '');
    await tester.pumpAndSettle();

    final mix = ref.read(blenderStartMixProvider);
    expect(mix.o2, closeTo(14.5, 0.001));
    expect(mix.he, closeTo(57.2, 0.001));
  });

  testWidgets('a cylinder holding neither oxygen nor helium is refused', (
    tester,
  ) async {
    final ref = await _pump(tester);
    ref.read(blenderStartPressureProvider.notifier).state = 40;
    ref.read(blenderStartMixProvider.notifier).state = const GasMix(o2: 0);
    await tester.pumpAndSettle();

    expect(find.text('Fill procedure'), findsNothing);
    expect(find.textContaining('oxygen'), findsOneWidget);
  });

  testWidgets('the reporter cylinder now blends', (tester) async {
    final ref = await _pump(tester);
    ref.read(blenderStartPressureProvider.notifier).state = 40;
    ref.read(blenderStartMixProvider.notifier).state = const GasMix(
      o2: 14.5,
      he: 57.2,
    );
    ref.read(blenderTargetMixProvider.notifier).state = const GasMix(
      o2: 15,
      he: 55,
    );
    await tester.pumpAndSettle();

    expect(find.text('Fill procedure'), findsOneWidget);
    // Z-factor: 10.2 / 86.9 / 62.8, in line with Multideco and arcusblender.
    expect(find.textContaining('+86.9'), findsWidgets);
  });
}
