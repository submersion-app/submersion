import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod/mod_assessment_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

GasLimitsInputs _inputs({
  ModCalculatorMode mode = ModCalculatorMode.ocTec,
  double o2 = 10,
  double he = 70,
  double minPpO2 = 0.16,
  double? target,
  WaterType waterType = WaterType.fresh,
}) => GasLimitsInputs(
  mode: mode,
  o2Percent: o2,
  hePercent: he,
  workingPpO2: 1.4,
  decoPpO2: 1.6,
  flushPpO2: 1.6,
  setpointBar: 1.1,
  minPpO2: minPpO2,
  endLimitMeters: 30,
  o2Narcotic: true,
  targetDepthMeters: target,
  waterType: waterType,
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  List<ModAssessment> assess(GasLimitsInputs inputs) => modAssessments(
    computeGasLimits(inputs),
    l10n: l10n,
    units: units,
    endLimitMeters: 30,
  );

  test('the hypoxic minimum depth is rounded up, never down', () {
    // Tx 10/70 at ppO2 0.16 in fresh water: 6.118 m, nearest would say 6.1.
    final hypoxic = assess(
      _inputs(),
    ).singleWhere((a) => a.text.startsWith('Hypoxic mix'));
    expect(hypoxic.text, contains('6.2m'));
    expect(hypoxic.severity, ModAssessmentSeverity.info);
  });

  test('OC: a target above the minimum depth is a danger', () {
    final items = assess(_inputs(target: 3));
    expect(
      items.where((a) => a.severity == ModAssessmentSeverity.danger),
      isNotEmpty,
    );
  });

  test('CCR: a shallow target on a hypoxic diluent is not a danger', () {
    // (The diluent's flush MOD near 150 m is rightly flagged for density;
    // only the hypoxia finding must not appear for the loop at 3 m.)
    final items = assess(_inputs(mode: ModCalculatorMode.ccrTec, target: 3));
    expect(
      items.where((a) => a.text.contains('the mix is hypoxic there')),
      isEmpty,
    );
  });

  test('CCR: setpoint above the flush ppO2 raises no warning by itself', () {
    // Setpoint 1.3 over a 1.1 flush is a valid setup: the setpoint is not
    // checked against the flush, only a target past the diluent MOD is.
    final items = assess(
      _inputs(
        mode: ModCalculatorMode.ccrTec,
        o2: 21,
        he: 35,
        waterType: WaterType.salt,
      ).copyWith(setpointBar: 1.3, flushPpO2: 1.1),
    );
    expect(items.where((a) => a.text.contains('setpoint')), isEmpty);
  });

  test('CCR: a target past the diluent MOD names the flush ppO2', () {
    final items = assess(
      _inputs(
        mode: ModCalculatorMode.ccrTec,
        o2: 21,
        he: 35,
        target: 80,
        waterType: WaterType.salt,
      ),
    );
    final danger = items.firstWhere(
      (a) => a.text.contains('deeper than the diluent MOD'),
    );
    expect(danger.severity, ModAssessmentSeverity.danger);
    expect(danger.text, contains('a flush there gives ppO₂'));
  });

  test('Rec: air is flagged beyond the recreational limit', () {
    final items = assess(_inputs(mode: ModCalculatorMode.rec, o2: 21, he: 0));
    expect(items.single.severity, ModAssessmentSeverity.warning);
  });
}
