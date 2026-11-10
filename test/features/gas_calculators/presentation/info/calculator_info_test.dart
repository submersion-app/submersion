import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/deco_calculator/presentation/info/deco_calculator_info.dart';
import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/info/calculator_info.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/info/surface_interval_info.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  String label(DiveTerm term) => diveTermEntry(l10n, units, term).term;
  List<String> labels(InfoContent content) =>
      content.terms.map((e) => e.term).toList();

  test('every calculator has a summary and how to use', () {
    for (final id in kGasCalculatorIds) {
      final content = calculatorInfo(l10n, units, id);
      expect(content.summary, isNotEmpty, reason: id);
      expect(content.howToUse, isNotEmpty, reason: id);
    }
  });

  test('the MOD sheet states its pressure rule in the diver\'s depth unit', () {
    const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));
    final metric = calculatorInfo(l10n, units, 'mod').background;
    final feet = calculatorInfo(l10n, imperial, 'mod').background;
    expect(metric, contains('1 bar per 10m'));
    expect(feet, contains('1 bar per 33ft'));
    expect(feet, isNot(contains(' m,')));
  });

  test('the MOD sheet says the Tec modes take depth pressure from water', () {
    final background = calculatorInfo(l10n, units, 'mod').background;
    expect(background, contains('pressure at depth'));
    expect(background, isNot(contains('surface pressure')));
  });

  test('the MOD sheet keeps the old About facts: MOD, EAD and END', () {
    final content = calculatorInfo(l10n, units, 'mod');
    expect(labels(content), contains(label(DiveTerm.mod)));
    expect(labels(content), contains(label(DiveTerm.ead)));
    expect(labels(content), contains(label(DiveTerm.end)));
    expect(content.background, contains('1 bar per 10m'));
  });

  group('Best Mix lists only what the card shows', () {
    test('Rec with a nitrox result: no rebreather gases, no trimix', () {
      final content = bestMixInfo(l10n, units, isCcr: false, hasHelium: false);
      expect(labels(content), contains(label(DiveTerm.end)));
      expect(labels(content), contains(label(DiveTerm.gasDensity)));
      expect(labels(content), isNot(contains(label(DiveTerm.trimix))));
      expect(labels(content), isNot(contains(label(DiveTerm.diluent))));
      expect(labels(content), isNot(contains(label(DiveTerm.bailout))));
    });

    test('CCR Tec with a helium result: diluent, bailout and trimix', () {
      final content = bestMixInfo(l10n, units, isCcr: true, hasHelium: true);
      expect(labels(content), contains(label(DiveTerm.trimix)));
      expect(labels(content), contains(label(DiveTerm.diluent)));
      expect(labels(content), contains(label(DiveTerm.bailout)));
    });
  });

  test('the MOD and density sheets keep the old About facts', () {
    expect(
      calculatorInfo(l10n, units, 'mod').background,
      contains('rounded down'),
    );
    expect(
      diveTermEntry(l10n, units, DiveTerm.eadd).body,
      contains('does not depend on the temperature'),
    );
  });

  test('Best Mix explains END and density, Consumption explains RMV', () {
    final best = calculatorInfo(l10n, units, 'best-mix');
    final consumption = calculatorInfo(l10n, units, 'consumption');
    expect(labels(best), contains(label(DiveTerm.end)));
    expect(labels(best), contains(label(DiveTerm.gasDensity)));
    expect(labels(consumption), contains(label(DiveTerm.rmv)));
    // The calculator takes and shows RMV only.
    expect(labels(consumption), isNot(contains(label(DiveTerm.sac))));
  });

  test('the deco calculator and surface interval tool have sheets', () {
    final deco = decoCalculatorInfo(l10n, units);
    final si = surfaceIntervalInfo(l10n, units);
    expect(deco.howToUse, isNotEmpty);
    expect(labels(si), contains(label(DiveTerm.leadingCompartment)));
    expect(si.background, isNotEmpty);
  });
}
