import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';

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
    // Each dive's lowest temperature, plain enough for the summary alone;
    // the cold-dives count is a different, threshold-based measure.
    ConditionTrendKind.minTemperature => null,
  };
  return InfoContent(
    title: title,
    summary: l10n.info_equipment_trend_summary,
    terms: diveTermEntries(l10n, units, [?term]),
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

/// The term behind an exposure unit, for the units that need one; days,
/// dives, hours and cycles explain themselves.
DiveTerm? exposureUnitTerm(ExposureUnit unit) => switch (unit) {
  ExposureUnit.saltHours => DiveTerm.saltWaterHours,
  ExposureUnit.coldDives => DiveTerm.coldDives,
  ExposureUnit.o2Hours => DiveTerm.highO2Hours,
  ExposureUnit.deepCycles => DiveTerm.deepCycles,
  ExposureUnit.days ||
  ExposureUnit.dives ||
  ExposureUnit.hours ||
  ExposureUnit.cycles => null,
};

/// The exposure card on an equipment item, explaining the [shown] units, the
/// ones with a chip on the card.
InfoContent equipmentExposureInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required Set<ExposureUnit> shown,
}) {
  return InfoContent(
    title: l10n.equipmentCondition_exposure_title,
    summary: l10n.info_equipment_exposure_summary,
    terms: diveTermEntries(l10n, units, [
      for (final unit in ExposureUnit.values)
        if (shown.contains(unit)) ?exposureUnitTerm(unit),
    ]),
  );
}
