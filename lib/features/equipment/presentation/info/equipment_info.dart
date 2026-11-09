import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';

/// A condition trend chart on an equipment item, titled as the chart is.
InfoContent equipmentTrendInfo(
  AppLocalizations l10n,
  UnitFormatter units,
  ConditionTrendKind kind, {
  required String title,
}) {
  final term = switch (kind) {
    ConditionTrendKind.cellGain => DiveTerm.cellGain,
    ConditionTrendKind.transmitterGapFraction => DiveTerm.transmitterDropouts,
    ConditionTrendKind.scrubberMinutes => DiveTerm.scrubber,
    ConditionTrendKind.minTemperature => DiveTerm.coldDives,
  };
  return InfoContent(
    title: title,
    summary: l10n.info_equipment_trend_summary,
    terms: diveTermEntries(l10n, units, [term]),
  );
}

/// The condition findings card on an equipment item.
InfoContent equipmentFindingsInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.equipmentCondition_findings_title,
    summary: l10n.info_equipment_findings_summary,
    terms: diveTermEntries(l10n, units, const [DiveTerm.conditionRules]),
  );
}

/// The exposure card on an equipment item.
InfoContent equipmentExposureInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.equipmentCondition_exposure_title,
    summary: l10n.info_equipment_exposure_summary,
    terms: diveTermEntries(l10n, units, const [
      DiveTerm.saltWaterHours,
      DiveTerm.coldDives,
      DiveTerm.highO2Hours,
      DiveTerm.deepCycles,
    ]),
  );
}
