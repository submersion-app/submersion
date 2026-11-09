import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('the MOD sheet keeps the old About facts: MOD, EAD and END', () {
    final content = calculatorInfo(l10n, units, 'mod');
    expect(labels(content), contains(label(DiveTerm.mod)));
    expect(labels(content), contains(label(DiveTerm.ead)));
    expect(labels(content), contains(label(DiveTerm.end)));
    expect(content.background, contains('1 bar per 10 m'));
  });

  test('Best Mix explains END and density, Consumption explains RMV', () {
    final best = calculatorInfo(l10n, units, 'best-mix');
    final consumption = calculatorInfo(l10n, units, 'consumption');
    expect(labels(best), contains(label(DiveTerm.end)));
    expect(labels(best), contains(label(DiveTerm.gasDensity)));
    expect(labels(consumption), contains(label(DiveTerm.rmv)));
  });

  test('the deco calculator and surface interval tool have sheets', () {
    final deco = decoCalculatorInfo(l10n, units);
    final si = surfaceIntervalInfo(l10n, units);
    expect(deco.howToUse, isNotEmpty);
    expect(labels(si), contains(label(DiveTerm.leadingCompartment)));
    expect(si.background, isNotEmpty);
  });
}
