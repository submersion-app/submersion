import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The planner's Gas options carry a per-plan "Best mix END". Issue #3093:
/// nothing read it, so changing it changed nothing on screen. The tank dialog
/// now offers the best mix for the plan's deepest point, judged against that
/// END, and fills the O2/He fields with it.
void main() {
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  Future<ProviderContainer> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: const SingleChildScrollView(child: PlanTankList()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(PlanTankList)));
  }

  /// The mix the dialog should offer at [depth] for [endMeters], from the
  /// diver's own ppO2 and O2-narcotic settings (the plan overrides neither).
  BestMixResult expectedAt(
    ProviderContainer container, {
    required double depth,
    required double endMeters,
  }) {
    final settings = container.read(settingsProvider);
    return computeBestMix(
      BestMixInputs(
        depthMeters: depth,
        ppO2Limit: settings.ppO2MaxWorking,
        endLimitMeters: endMeters,
        o2Narcotic: settings.o2Narcotic,
      ),
    );
  }

  Future<void> openAddTank(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
  }

  Finder bestMixButton() => find.textContaining('Best mix for');

  testWidgets('fills O2 and He with the best mix for the plan depth', (
    tester,
  ) async {
    final container = await pumpList(tester);
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSimplePlan(maxDepth: 60, bottomTimeMinutes: 20);
    notifier.updateGasOptions(bestMixEndMeters: 30);
    await tester.pumpAndSettle();

    final expected = expectedAt(
      container,
      depth: 60,
      endMeters: 30,
    ).recommended.mix;
    // At 60 m an END of 30 m needs helium, so the offer is a trimix.
    expect(expected.he, greaterThan(0));

    await openAddTank(tester);
    expect(find.text('Best mix for 60m: ${expected.name}'), findsOneWidget);

    await tester.tap(bestMixButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final added = container.read(divePlanNotifierProvider).tanks.last;
    expect(added.gasMix.o2, expected.o2);
    expect(added.gasMix.he, expected.he);
  });

  testWidgets('a tighter best-mix END fills more helium', (tester) async {
    final container = await pumpList(tester);
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSimplePlan(maxDepth: 60, bottomTimeMinutes: 20);

    Future<double> heFilledFor(double endMeters) async {
      notifier.updateGasOptions(bestMixEndMeters: endMeters);
      await tester.pumpAndSettle();
      await openAddTank(tester);
      await tester.tap(bestMixButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      return container.read(divePlanNotifierProvider).tanks.last.gasMix.he;
    }

    final loose = await heFilledFor(40);
    final tight = await heFilledFor(20);
    expect(tight, greaterThan(loose));
    expect(
      tight,
      expectedAt(container, depth: 60, endMeters: 20).recommended.mix.he,
    );
  });

  testWidgets('filling the best mix clears an earlier O2 error', (
    tester,
  ) async {
    final container = await pumpList(tester);
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 60, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
    await openAddTank(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'O₂ %'), '150');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final error = find.text(
      lookupAppLocalizations(const Locale('en')).numberInput_percentRange,
    );
    expect(error, findsOneWidget);

    await tester.tap(bestMixButton());
    await tester.pumpAndSettle();

    expect(error, findsNothing);
  });

  group('on a CCR plan', () {
    /// The mix offered at 60 m when gated by [ppO2Limit] instead of the
    /// bottom ceiling.
    GasMix mixFor(ProviderContainer container, double ppO2Limit) {
      final settings = container.read(settingsProvider);
      return computeBestMix(
        BestMixInputs(
          depthMeters: 60,
          ppO2Limit: ppO2Limit,
          endLimitMeters: 30,
          o2Narcotic: settings.o2Narcotic,
        ),
      ).recommended.mix;
    }

    Future<ProviderContainer> pumpCcr(WidgetTester tester) async {
      final container = await pumpList(tester);
      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.addSimplePlan(maxDepth: 60, bottomTimeMinutes: 20);
      notifier.updateMode(PlanMode.ccr);
      await tester.pumpAndSettle();
      return container;
    }

    /// Opens the edit dialog of the cylinder named [label] on its chip.
    Future<void> editTank(WidgetTester tester, String label) async {
      await tester.tap(find.widgetWithText(InputChip, label));
      await tester.pumpAndSettle();
    }

    testWidgets('the breathed diluent gets a mix sized for the diluent MOD '
        'ppO2', (tester) async {
      final container = await pumpCcr(tester);
      final settings = container.read(settingsProvider);
      final diluent = mixFor(container, settings.ccrDiluentModPpO2);
      // The two ceilings must differ at 60 m, or this proves nothing.
      expect(diluent, isNot(mixFor(container, settings.ppO2MaxWorking)));
      final breathed = container.read(divePlanNotifierProvider).tanks.first;

      await editTank(tester, breathed.name ?? breathed.gasMix.name);

      expect(find.text('Best mix for 60m: ${diluent.name}'), findsOneWidget);
    });

    testWidgets('unticking Diluent switches the breathed tank to the bottom '
        'mix', (tester) async {
      final container = await pumpCcr(tester);
      final notifier = container.read(divePlanNotifierProvider.notifier);
      final bottom = mixFor(
        container,
        container.read(settingsProvider).ppO2MaxWorking,
      );
      final breathed = container.read(divePlanNotifierProvider).tanks.first;
      // The Diluent tile is disabled while its cylinder is the plan's only
      // one (nothing left to fall back on), so a second diluent cylinder is
      // added first, same as a diver carrying a spare would.
      notifier.addTank(
        const DiveTank(
          id: 'second-diluent',
          name: 'Second diluent',
          volume: 12,
          startPressure: 200,
          gasMix: GasMix(o2: 21, he: 35),
          role: TankRole.diluent,
        ),
      );
      await tester.pumpAndSettle();

      await editTank(tester, breathed.name ?? breathed.gasMix.name);
      // The explicit Diluent tile (#3220) replaced the old "Bailout gas"
      // checkbox: unticking it, rather than ticking a bailout flag, is what
      // now drops the cylinder out of the diluent slot and onto the bottom
      // mix like any other open-circuit bailout gas.
      await tester.tap(find.text('Diluent'));
      await tester.pumpAndSettle();

      expect(find.text('Best mix for 60m: ${bottom.name}'), findsOneWidget);
    });

    testWidgets('a cylinder no segment breathes is a bailout and gets the '
        'bottom mix', (tester) async {
      final container = await pumpCcr(tester);
      final bottom = mixFor(
        container,
        container.read(settingsProvider).ppO2MaxWorking,
      );

      await openAddTank(tester);

      expect(find.text('Best mix for 60m: ${bottom.name}'), findsOneWidget);
    });

    testWidgets(
      'typing 100% O2 into a new cylinder does not claim the oxygen slot '
      'on a CCR plan (#3220 is slot-based, not mix-based)',
      (tester) async {
        await pumpCcr(tester);
        await openAddTank(tester);
        final o2Field = find.widgetWithText(TextFormField, 'O₂ %');

        // CCR already holds both loop slots once in CCR mode (#3220): a new
        // third cylinder stays open-circuit bailout no matter its mix, so
        // typing 100% here does not make it the oxygen supply and the offer
        // (now the bottom mix, since the cylinder is bailout) keeps showing.
        await tester.enterText(o2Field, '100');
        await tester.pumpAndSettle();
        expect(bestMixButton(), findsOneWidget);

        // Ticking Diluent offers the diluent mix instead, same as any other
        // cylinder claiming that slot.
        await tester.tap(find.text('Diluent'));
        await tester.pumpAndSettle();
        expect(bestMixButton(), findsOneWidget);
      },
    );

    testWidgets(
      'filling a 100% O2 offer on a new cylinder does not make it the '
      'oxygen supply (#3220 is slot-based, not mix-based)',
      (tester) async {
        final container = await pumpList(tester);
        final notifier = container.read(divePlanNotifierProvider.notifier);
        // At 3 m the bottom ceiling allows pure O2, so the offer fills 100%.
        notifier.addSimplePlan(maxDepth: 3, bottomTimeMinutes: 20);
        notifier.updateMode(PlanMode.ccr);
        await tester.pumpAndSettle();
        await openAddTank(tester);

        await tester.tap(bestMixButton());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(TextFormField, '100'),
          findsOneWidget,
          reason: 'the fill should have written 100% O2',
        );
        // Still open-circuit bailout, not the oxygen slot: the offer (now
        // matching the field) stays visible rather than being hidden.
        expect(bestMixButton(), findsOneWidget);
      },
    );

    testWidgets('the oxygen supply is never offered a mix to overwrite it', (
      tester,
    ) async {
      final container = await pumpCcr(tester);
      container
          .read(divePlanNotifierProvider.notifier)
          .addTank(
            const DiveTank(
              id: 'o2-supply',
              name: 'O2 supply',
              volume: 3,
              startPressure: 200,
              gasMix: GasMix(o2: 100),
              // The locked oxygen slot (#3220) is explicit, not inferred
              // from the mix -- set here the way CcrLoopSlots would set
              // it on the real slot cylinder.
              role: TankRole.oxygenSupply,
            ),
          );
      await tester.pumpAndSettle();

      await editTank(tester, 'O2 supply');

      expect(bestMixButton(), findsNothing);
    });
  });

  testWidgets('offers no best mix while the plan has no depth', (tester) async {
    await pumpList(tester);

    await openAddTank(tester);

    expect(bestMixButton(), findsNothing);
  });
}
