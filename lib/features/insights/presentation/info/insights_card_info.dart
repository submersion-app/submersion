import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/presentation/info/equipment_info.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// SAC or RMV, whichever lane a gas card shows.
List<DiveTerm> gasLaneTerms({required bool isRmv}) => [
  isRmv ? DiveTerm.rmv : DiveTerm.sac,
];

/// The term behind a Dive focus measure, for the measures that need one.
DiveTerm? _focusTerm(FocusMetric metric) => switch (metric) {
  FocusMetric.rmv => DiveTerm.rmv,
  FocusMetric.sac => DiveTerm.sac,
  FocusMetric.avgDepth => DiveTerm.meanDepth,
  FocusMetric.runtime => DiveTerm.runtime,
  FocusMetric.bottomTime => DiveTerm.bottomTime,
  FocusMetric.surfaceInterval => DiveTerm.surfaceInterval,
  FocusMetric.cns => DiveTerm.cns,
  FocusMetric.otu => DiveTerm.otu,
  _ => null,
};

/// The Dive focus results, explaining the chosen [metric] and the sentence
/// that picks the dives.
InfoContent focusInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required FocusMetric metric,
}) {
  return InfoContent(
    title: l10n.insights_focus_title,
    summary: l10n.info_insights_focus_summary,
    terms: diveTermEntries(l10n, units, [?_focusTerm(metric)]),
    howToUse: l10n.info_insights_focus_howToUse,
  );
}

/// The Overview stat cards.
InfoContent overviewStatsInfo(AppLocalizations l10n, UnitFormatter units) {
  return termsInfo(
    l10n,
    units,
    title: l10n.insights_category_overview_title,
    summary: l10n.info_insights_overviewStats_summary,
    terms: const [DiveTerm.avgMaxDepth],
  );
}

/// The equipment exposure ranking, explaining the chosen [unit].
InfoContent exposureInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required ExposureUnit unit,
}) {
  return termsInfo(
    l10n,
    units,
    title: l10n.insights_equipment_exposure_title,
    summary: l10n.info_insights_exposure_summary,
    terms: [?exposureUnitTerm(unit)],
  );
}
