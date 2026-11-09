import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';
import 'package:submersion/shared/widgets/info_sheet/info_units.dart';

/// The overlays the profile chart draws right now: each one the dive has data
/// for and the legend has switched on, in legend order.
List<DiveTerm> profileOverlayTerms(
  ProfileLegendConfig config,
  ProfileLegendState state,
) {
  return [
    if (config.hasNdlData && state.showNdl) DiveTerm.ndl,
    if (config.hasCeilingCurve && state.showCeiling) DiveTerm.ceiling,
    if (config.hasDecoStopCurve && state.showDecoStops) DiveTerm.decoStops,
    if (config.hasTtsData && state.showTts) DiveTerm.tts,
    if (config.hasGtrData && state.showGtr) DiveTerm.gtr,
    if (config.hasCnsData && state.showCns) DiveTerm.cns,
    if (config.hasOtuData && state.showOtu) DiveTerm.otu,
    if (config.hasPpO2Data && state.showPpO2) DiveTerm.ppO2,
    if (config.hasPpN2Data && state.showPpN2) DiveTerm.ppN2,
    if (config.hasPpHeData && state.showPpHe) DiveTerm.ppHe,
    if (config.hasO2CellData && state.showO2Cells) DiveTerm.o2Cells,
    if (config.hasModData && state.showMod) DiveTerm.mod,
    if (config.hasDensityData && state.showDensity) DiveTerm.gasDensity,
    if (config.hasGfData && state.showGf) DiveTerm.gf99,
    if (config.hasSurfaceGfData && state.showSurfaceGf) DiveTerm.surfaceGf,
    if (config.hasMeanDepthData && state.showMeanDepth) DiveTerm.meanDepth,
    if (config.hasSacCurve && state.showSac) DiveTerm.sac,
    if (config.hasAscentRates &&
        (state.showAscentRateColors || state.showAscentRateLine))
      DiveTerm.ascentRate,
    if (config.hasGasSwitches && state.showGasSwitchMarkers)
      DiveTerm.gasSwitchMarkers,
    if (config.hasLateGasSwitches && state.showLateGasSwitches)
      DiveTerm.lateGasSwitch,
    if (config.hasComputedEvents && state.showComputedEvents)
      DiveTerm.computedEvents,
  ];
}

/// Overlays whose values come from the dive computer or the app's model,
/// as the decompression settings choose.
const _sourceSelectable = {
  DiveTerm.ndl,
  DiveTerm.decoStops,
  DiveTerm.tts,
  DiveTerm.gtr,
  DiveTerm.cns,
};

/// The Dive Profile card, listing [overlayTerms] (from
/// [profileOverlayTerms]).
InfoContent diveProfileInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required List<DiveTerm> overlayTerms,
}) {
  return InfoContent(
    title: l10n.diveLog_detail_section_diveProfile,
    summary: l10n.info_diveLog_profile_summary,
    terms: diveTermEntries(l10n, units, [
      ...overlayTerms,
      if (overlayTerms.any(_sourceSelectable.contains)) DiveTerm.sourceDcCalc,
    ]),
    background: l10n.info_diveLog_profile_background,
    howToUse: l10n.info_diveLog_profile_howToUse,
  );
}

/// [diveProfileInfo] for the chart under [context]: the overlays its
/// [ProfileLegendSnapshotScope] says it last drew.
InfoContent diveProfileInfoFor(BuildContext context) {
  final config = ProfileLegendSnapshotScope.maybeOf(context)?.config;
  final state = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(profileLegendProvider);
  return diveProfileInfo(
    context.l10n,
    infoUnits(context),
    overlayTerms: config == null
        ? const []
        : profileOverlayTerms(config, state),
  );
}

/// The Range Stats panel under the profile.
InfoContent rangeStatsInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required bool showsSac,
  required bool showsRmv,
}) {
  return InfoContent(
    title: l10n.diveLog_rangeStats_title,
    summary: l10n.info_diveLog_rangeStats_summary,
    terms: diveTermEntries(l10n, units, [
      DiveTerm.avgVerticalSpeed,
      if (showsSac) DiveTerm.sac,
      if (showsRmv) DiveTerm.rmv,
    ]),
  );
}

/// The legend config the profile chart last built, for the info icon in the
/// card header above it.
///
/// The chart works out which overlays the dive has data for while it builds;
/// the header cannot see that. The chart writes its config here and the info
/// sheet reads it when tapped. A plain field: writing it rebuilds nothing.
class ProfileLegendSnapshot {
  ProfileLegendConfig? config;
}

/// Gives the profile chart below it a [ProfileLegendSnapshot] to fill.
class ProfileLegendSnapshotScope extends StatefulWidget {
  const ProfileLegendSnapshotScope({super.key, required this.child});

  final Widget child;

  /// The nearest snapshot, without registering a dependency.
  static ProfileLegendSnapshot? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<_ProfileLegendSnapshotInherited>()
      ?.snapshot;

  @override
  State<ProfileLegendSnapshotScope> createState() =>
      _ProfileLegendSnapshotScopeState();
}

class _ProfileLegendSnapshotScopeState
    extends State<ProfileLegendSnapshotScope> {
  final _snapshot = ProfileLegendSnapshot();

  @override
  Widget build(BuildContext context) =>
      _ProfileLegendSnapshotInherited(snapshot: _snapshot, child: widget.child);
}

class _ProfileLegendSnapshotInherited extends InheritedWidget {
  const _ProfileLegendSnapshotInherited({
    required this.snapshot,
    required super.child,
  });

  final ProfileLegendSnapshot snapshot;

  @override
  bool updateShouldNotify(_ProfileLegendSnapshotInherited oldWidget) =>
      !identical(snapshot, oldWidget.snapshot);
}
