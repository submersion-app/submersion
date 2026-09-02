// Imperial coverage for the costing card.
//
// The existing widget tests all run in litres, which is exactly why two unit
// defects survived to review on PR #1215: the volume column converted twice
// and the price never converted at all, and neither shows up in metric.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_billing_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Cubic feet per litre, as `VolumeUnit.convert` uses.
const double _cuftPerLiter = 0.0353147;

Future<WidgetRef> _pump(WidgetTester tester, VolumeUnit unit) async {
  await tester.binding.setSurfaceSize(const Size(900, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  late WidgetRef captured;
  // Keyed on the unit so a second pump in one test builds a genuinely fresh
  // scope. Without it Flutter reuses the element tree, the override is not
  // swapped, and the "same gas, either unit" comparison silently measures
  // metric twice.
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(unit),
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(
            AppSettings(volumeUnit: unit, defaultCurrency: 'USD'),
          ),
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
                return const BlenderBillingCard();
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

Finder _priceField(int slot) => find
    .byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.labelText ?? '').contains('Price per 100'),
    )
    .at(slot);

void main() {
  testWidgets('a price typed per 100 cu ft is stored per 100 litres', (
    tester,
  ) async {
    final ref = await _pump(tester, VolumeUnit.cubicFeet);

    await tester.enterText(_priceField(0), '7.99');
    await tester.pumpAndSettle();

    // 7.99 per 100 cu ft is 0.282 per 100 L: the same gas at the same money,
    // in a unit 28 times smaller. Storing 7.99 raw charged 28 times over.
    expect(
      ref.read(blenderGasPricesProvider)[0],
      closeTo(7.99 * _cuftPerLiter, 1e-9),
    );
  });

  testWidgets('a price typed per 100 L is stored as typed', (tester) async {
    final ref = await _pump(tester, VolumeUnit.liters);

    await tester.enterText(_priceField(0), '7.99');
    await tester.pumpAndSettle();

    expect(ref.read(blenderGasPricesProvider)[0], closeTo(7.99, 1e-9));
  });

  testWidgets('the same gas costs the same in either unit', (tester) async {
    // An AL80 (11.1 L of water) taking 50 bar of oxygen, priced identically in
    // each system. The bill must not depend on which unit the diver reads in.
    Future<double> totalFor(VolumeUnit unit, String price) async {
      final ref = await _pump(tester, unit);
      ref.read(blenderCylinderLitersProvider.notifier).state = 11.1;
      await tester.pumpAndSettle();
      await tester.enterText(_priceField(0), price);
      await tester.enterText(_priceField(1), price);
      await tester.enterText(_priceField(2), price);
      await tester.pumpAndSettle();
      return ref.read(blenderBillingProvider).total!;
    }

    final metric = await totalFor(VolumeUnit.liters, '1');
    // 1 per 100 L is 28.3168 per 100 cu ft.
    final imperial = await totalFor(VolumeUnit.cubicFeet, '28.3168');

    expect(imperial, closeTo(metric, metric * 0.001));
  });

  testWidgets('the volume column is converted exactly once', (tester) async {
    final ref = await _pump(tester, VolumeUnit.cubicFeet);
    ref.read(blenderCylinderLitersProvider.notifier).state = 11.1;
    ref.read(blenderGasPricesProvider.notifier).state = const [1.0, 1.0, 1.0];
    await tester.pumpAndSettle();

    final liters = ref.read(blenderBillingProvider).lines.first.freeGasLiters;
    final expected = (liters * _cuftPerLiter).toStringAsFixed(0);

    // Converting twice printed "0 cuft" for hundreds of litres of gas.
    expect(find.text('$expected cuft'), findsWidgets);
    expect(expected, isNot('0'));
  });
}
