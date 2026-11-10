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

  group('results sections', () {
    test('the deco schedule explains its table columns', () {
      final content = planDecoScheduleInfo(l10n, units);
      expect(content.summary, isNotEmpty);
      expect(labels(content), contains(label(DiveTerm.decoStops)));
      expect(labels(content), contains(label(DiveTerm.end)));
    });

    test('the gas section explains turn pressure and minimum gas', () {
      final content = planGasInfo(l10n, units);
      expect(labels(content), contains(label(DiveTerm.turnPressure)));
      expect(labels(content), contains(label(DiveTerm.minGas)));
    });

    test('the carry card lists OTU only when it shows it', () {
      final withOtu = planCarryInfo(
        l10n,
        units,
        title: 'Carried into Dive 2',
        showsOtu: true,
      );
      final withoutOtu = planCarryInfo(
        l10n,
        units,
        title: 'Carried into Dive 2',
        showsOtu: false,
      );
      expect(withOtu.title, 'Carried into Dive 2');
      expect(labels(withOtu), contains(label(DiveTerm.otu)));
      expect(labels(withoutOtu), isNot(contains(label(DiveTerm.otu))));
      expect(labels(withoutOtu), contains(label(DiveTerm.cns)));
    });

    test('a section with no terms draws none', () {
      final content = termsInfo(
        l10n,
        units,
        title: 'Range',
        summary: 'How far the gas lasts.',
      );
      expect(content.terms, isEmpty);
    });
  });

  group('Dive Lab', () {
    test('the delta table explains the what-if column and GF99', () {
      final content = labDeltaInfo(l10n, units);
      expect(content.summary, isNotEmpty);
      expect(labels(content), contains(label(DiveTerm.whatIf)));
      expect(labels(content), contains(label(DiveTerm.gf99)));
      expect(labels(content), contains(label(DiveTerm.ceilingViolation)));
    });

    test('the tissue strips explain the heat map', () {
      final content = labTissuesInfo(l10n, units);
      expect(labels(content), contains(label(DiveTerm.heatMap)));
      expect(labels(content), contains(label(DiveTerm.tissueLoad)));
    });

    test('the buoyancy rows explain lift and ditchable weight', () {
      final content = labBuoyancyInfo(l10n, units);
      expect(labels(content), contains(label(DiveTerm.peakLift)));
      expect(labels(content), contains(label(DiveTerm.minDitchable)));
    });

    test('the interventions sheet has a summary and no terms', () {
      final content = labInterventionsInfo(l10n, units);
      expect(content.summary, isNotEmpty);
      expect(content.terms, isEmpty);
    });
  });
}
