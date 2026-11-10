import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The Dive Lab tile grid.
InfoContent labTilesInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.diveLab_panel_delta,
    summary: l10n.info_diveLab_tiles_summary,
    terms: diveTermEntries(l10n, units, const [
      DiveTerm.tts,
      DiveTerm.decoStops,
      DiveTerm.surfaceGf,
      DiveTerm.cns,
    ]),
  );
}

/// The Dive Lab delta table.
InfoContent labDeltaInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.diveLab_panel_delta,
    summary: l10n.info_diveLab_delta_summary,
    terms: diveTermEntries(l10n, units, const [
      DiveTerm.whatIf,
      DiveTerm.deepestStop,
      DiveTerm.gf99,
      DiveTerm.surfaceGf,
      DiveTerm.otu,
      DiveTerm.maxPpO2,
      DiveTerm.minGasMargin,
      DiveTerm.gasOutTime,
      DiveTerm.ceilingViolation,
    ]),
  );
}

/// The Dive Lab tissue strips.
InfoContent labTissuesInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.diveLab_panel_tissues,
    summary: l10n.info_diveLab_tissues_summary,
    terms: diveTermEntries(l10n, units, const [
      DiveTerm.tissueLoad,
      DiveTerm.heatMap,
    ]),
  );
}

/// The Dive Lab buoyancy rows.
InfoContent labBuoyancyInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.diveLab_panel_buoyancy,
    summary: l10n.info_diveLab_buoyancy_summary,
    terms: diveTermEntries(l10n, units, const [
      DiveTerm.netBuoyancy,
      DiveTerm.peakLift,
      DiveTerm.minDitchable,
    ]),
  );
}

/// The Dive Lab interventions sheet.
InfoContent labInterventionsInfo(AppLocalizations l10n, UnitFormatter units) {
  return InfoContent(
    title: l10n.diveLab_sheet_title,
    summary: l10n.info_diveLab_interventions_summary,
  );
}
