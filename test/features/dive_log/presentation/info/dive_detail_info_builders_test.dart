import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/info/buoyancy_info.dart';
import 'package:submersion/features/dive_log/presentation/info/cylinders_info.dart';
import 'package:submersion/features/dive_log/presentation/info/deco_status_info.dart';
import 'package:submersion/features/dive_log/presentation/info/dive_details_info.dart';
import 'package:submersion/features/dive_log/presentation/info/dive_profile_info.dart';
import 'package:submersion/features/dive_log/presentation/info/o2_toxicity_info.dart';
import 'package:submersion/features/dive_log/presentation/info/safety_review_info.dart';
import 'package:submersion/features/dive_log/presentation/info/sac_segments_info.dart';
import 'package:submersion/features/dive_log/presentation/info/tissue_loading_info.dart';
import 'package:submersion/features/dive_log/presentation/info/water_conditions_info.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
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

  group('profile', () {
    test('lists only overlays that have data and are switched on', () {
      const config = ProfileLegendConfig(
        hasNdlData: true,
        hasCeilingCurve: true,
        hasPpO2Data: true,
        hasPpHeData: false,
      );
      const state = ProfileLegendState(
        showNdl: true,
        showCeiling: false,
        showPpO2: true,
        showPpHe: true,
      );

      final terms = profileOverlayTerms(config, state);
      expect(terms, contains(DiveTerm.ndl));
      expect(terms, contains(DiveTerm.ppO2));
      expect(terms, isNot(contains(DiveTerm.ceiling)));
      expect(terms, isNot(contains(DiveTerm.ppHe)));
    });

    test('an air dive sheet has no ppHe or setpoint', () {
      const config = ProfileLegendConfig(hasPpO2Data: true, hasNdlData: true);
      const state = ProfileLegendState(
        showPpO2: true,
        showNdl: true,
        showPpHe: true,
      );
      final content = diveProfileInfo(
        l10n,
        units,
        overlayTerms: profileOverlayTerms(config, state),
      );

      expect(labels(content), isNot(contains(label(DiveTerm.ppHe))));
      expect(labels(content), isNot(contains(label(DiveTerm.setpoint))));
    });

    test('no overlays give no terms', () {
      final content = diveProfileInfo(l10n, units, overlayTerms: const []);
      expect(content.terms, isEmpty);
      expect(content.summary, isNotEmpty);
    });

    test('source-selectable overlays bring the DC or calculated term', () {
      const config = ProfileLegendConfig(hasNdlData: true);
      const state = ProfileLegendState(showNdl: true);
      final content = diveProfileInfo(
        l10n,
        units,
        overlayTerms: profileOverlayTerms(config, state),
      );
      expect(labels(content), contains(label(DiveTerm.sourceDcCalc)));
    });
  });

  group('deco status', () {
    test('in deco shows the ceiling and not NDL', () {
      final content = decoStatusInfo(l10n, units, inDeco: true, hasStops: true);
      expect(labels(content), contains(label(DiveTerm.ceiling)));
      expect(labels(content), contains(label(DiveTerm.decoStops)));
      expect(labels(content), isNot(contains(label(DiveTerm.ndl))));
    });

    test('no deco shows NDL and not the ceiling', () {
      final content = decoStatusInfo(
        l10n,
        units,
        inDeco: false,
        hasStops: false,
      );
      expect(labels(content), contains(label(DiveTerm.ndl)));
      expect(labels(content), isNot(contains(label(DiveTerm.ceiling))));
      expect(labels(content), isNot(contains(label(DiveTerm.decoStops))));
    });
  });

  test('oxygen toxicity always explains the OTU windows the card shows', () {
    final content = o2ToxicityInfo(
      l10n,
      units,
      showsDetails: false,
      showsTimeAbove: true,
    );
    expect(labels(content), contains(label(DiveTerm.cns)));
    expect(labels(content), contains(label(DiveTerm.otuWindows)));
    expect(labels(content), isNot(contains(label(DiveTerm.maxPpO2))));
    expect(labels(content), isNot(contains(label(DiveTerm.timeAboveLimit))));
  });

  test('oxygen toxicity lists max ppO2 and time above with the details', () {
    final content = o2ToxicityInfo(
      l10n,
      units,
      showsDetails: true,
      showsTimeAbove: true,
    );
    expect(labels(content), contains(label(DiveTerm.maxPpO2)));
    expect(labels(content), contains(label(DiveTerm.timeAboveLimit)));
  });

  group('tissue loading', () {
    test('helium term only on helium dives', () {
      final air = tissueLoadingInfo(
        l10n,
        units,
        view: TissueVizMode.heatMap,
        hasHelium: false,
      );
      final tmx = tissueLoadingInfo(
        l10n,
        units,
        view: TissueVizMode.heatMap,
        hasHelium: true,
      );
      expect(labels(air), isNot(contains(label(DiveTerm.nitrogenHelium))));
      expect(labels(tmx), contains(label(DiveTerm.nitrogenHelium)));
    });

    test('the chosen view decides heat map or stacked area', () {
      final heat = tissueLoadingInfo(
        l10n,
        units,
        view: TissueVizMode.heatMap,
        hasHelium: false,
      );
      final stacked = tissueLoadingInfo(
        l10n,
        units,
        view: TissueVizMode.stackedArea,
        hasHelium: false,
      );
      final none = tissueLoadingInfo(l10n, units, view: null, hasHelium: false);
      expect(labels(heat), contains(label(DiveTerm.heatMap)));
      expect(labels(heat), isNot(contains(label(DiveTerm.stackedArea))));
      expect(labels(stacked), contains(label(DiveTerm.stackedArea)));
      expect(labels(none), isNot(contains(label(DiveTerm.heatMap))));
    });
  });

  test('safety review lists only the rules it found', () {
    final content = safetyReviewInfo(
      l10n,
      units,
      rules: {SafetyRuleId.rapidAscent, SafetyRuleId.sawtoothProfile},
    );
    expect(labels(content), [
      label(DiveTerm.ascentRate),
      label(DiveTerm.sawtooth),
    ]);
  });

  test('cylinders on an open-circuit air dive have no loop or trimix', () {
    final content = cylindersInfo(
      l10n,
      units,
      hasNitrox: false,
      hasTrimix: false,
      isRebreather: false,
      hasBreathingGas: true,
      showsSac: true,
      showsRmv: false,
    );
    expect(labels(content), contains(label(DiveTerm.mod)));
    expect(labels(content), contains(label(DiveTerm.sac)));
    expect(labels(content), isNot(contains(label(DiveTerm.loop))));
    expect(labels(content), isNot(contains(label(DiveTerm.trimix))));
    expect(labels(content), isNot(contains(label(DiveTerm.rmv))));
  });

  test('gas segments explain the selector only when it is shown', () {
    final both = sacSegmentsInfo(
      l10n,
      units,
      showsSac: true,
      showsRmv: true,
      hasSelector: true,
    );
    final one = sacSegmentsInfo(
      l10n,
      units,
      showsSac: true,
      showsRmv: false,
      hasSelector: false,
    );
    expect(both.howToUse, isNotNull);
    expect(one.howToUse, isNull);
    expect(labels(one), isNot(contains(label(DiveTerm.rmv))));
  });

  test('details lists gradient factors only when the dive has them', () {
    final content = diveDetailsInfo(
      l10n,
      units,
      showsSac: false,
      showsRmv: false,
      hasGradientFactors: false,
    );
    expect(labels(content), [label(DiveTerm.diveModes)]);
  });

  test('buoyancy minimum ditchable weight follows the weight unit', () {
    const imperial = UnitFormatter(AppSettings(weightUnit: WeightUnit.pounds));
    final content = buoyancyInfo(
      l10n,
      imperial,
      hasDrysuitGas: false,
      canAdjust: true,
    );
    final ditch = content.terms.firstWhere(
      (e) => e.term == label(DiveTerm.minDitchable),
    );
    expect(ditch.body, contains('lb'));
    expect(labels(content), isNot(contains(label(DiveTerm.drysuitGas))));
    expect(content.howToUse, isNotNull);
  });

  test('water conditions lists only the readings present', () {
    final content = waterConditionsInfo(
      l10n,
      units,
      hasDhw: true,
      hasAnomaly: false,
      hasAlert: false,
    );
    expect(labels(content), [label(DiveTerm.degreeHeatingWeeks)]);
  });

  test('a dive with only suit inflation lists no gas terms', () {
    final content = cylindersInfo(
      l10n,
      units,
      hasNitrox: false,
      hasTrimix: false,
      isRebreather: false,
      hasBreathingGas: false,
      showsSac: true,
      showsRmv: true,
    );
    for (final term in [
      DiveTerm.mod,
      DiveTerm.mnd,
      DiveTerm.ppO2,
      DiveTerm.sac,
      DiveTerm.rmv,
    ]) {
      expect(labels(content), isNot(contains(label(term))), reason: '$term');
    }
  });
}
