import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/presentation/info/lab_info.dart';
import 'package:submersion/features/planner/presentation/info/plan_results_info.dart';
import 'package:submersion/features/planner/presentation/info/plan_setup_info.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  String label(DiveTerm term) => diveTermEntry(l10n, units, term).term;
  List<String> labels(InfoContent content) =>
      content.terms.map((e) => e.term).toList();

  test('results tiles explain TTS in deco and NDL otherwise', () {
    final deco = planResultsTilesInfo(l10n, units, inDeco: true);
    final noDeco = planResultsTilesInfo(l10n, units, inDeco: false);
    expect(labels(deco), contains(label(DiveTerm.tts)));
    expect(labels(deco), isNot(contains(label(DiveTerm.ndl))));
    expect(labels(noDeco), contains(label(DiveTerm.ndl)));
    expect(labels(noDeco), isNot(contains(label(DiveTerm.tts))));
  });

  test('every setup section has a summary and how to use', () {
    for (final key in planSetupSectionKeys) {
      final content = planSetupSectionInfo(l10n, units, key, title: key);
      expect(content.summary, isNotEmpty, reason: key);
      expect(content.howToUse, isNotEmpty, reason: key);
    }
  });

  test('the gas section has no rebreather terms', () {
    final gas = planSetupSectionInfo(l10n, units, 'gas', title: 'Gas');
    expect(labels(gas), isNot(contains(label(DiveTerm.setpoint))));
    expect(labels(gas), isNot(contains(label(DiveTerm.diluent))));
  });

  test('an unknown section key gives no sheet', () {
    expect(planSetupSectionKeys.contains('unknown'), isFalse);
  });

  test('the Dive Lab tile grid explains its four tiles', () {
    final content = labTilesInfo(l10n, units);
    expect(labels(content), [
      label(DiveTerm.tts),
      label(DiveTerm.decoStops),
      label(DiveTerm.surfaceGf),
      label(DiveTerm.cns),
    ]);
  });
}
