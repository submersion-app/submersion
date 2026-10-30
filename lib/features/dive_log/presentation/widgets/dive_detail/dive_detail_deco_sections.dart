import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_3d/presentation/pages/dive_3d_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_deco_status_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_analysis_retention.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_switch_efficiency_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_toxicity_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_loading_withheld_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Deco Status section: the deco card with the O2 exposure card beneath
/// it, the arrangement the two have always had.
class DiveDecoStatusSection extends ConsumerWidget {
  const DiveDecoStatusSection({
    super.key,
    required this.dive,
    required this.retention,
    required this.stretch,
  });

  final Dive dive;
  final DiveDetailAnalysisRetention retention;

  /// Fill the height the parent gives the column, which the Deco Status /
  /// Tissue Loading pair relies on to keep both of its columns the same
  /// height.
  final bool stretch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = _decoPanelCards(context, ref, dive, retention);
    if (cards == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (stretch) Expanded(child: cards.deco) else cards.deco,
        const SizedBox(height: 8),
        cards.o2,
        if (cards.gasSwitches != null) ...[
          const SizedBox(height: 8),
          cards.gasSwitches!,
        ],
      ],
    );
  }
}

/// The Tissue Loading section: the heat map / stacked-area card on its own.
class DiveTissueLoadingSection extends ConsumerWidget {
  const DiveTissueLoadingSection({
    super.key,
    required this.dive,
    required this.retention,
    required this.expand,
  });

  final Dive dive;
  final DiveDetailAnalysisRetention retention;
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = _decoPanelCards(context, ref, dive, retention);
    if (cards == null) return const SizedBox.shrink();
    return cards.tissue(expand: expand);
  }
}

String _formatTimestamp(int seconds) {
  final minutes = seconds ~/ 60;
  final secs = seconds % 60;
  return '$minutes:${secs.toString().padLeft(2, '0')}';
}

/// The three cards the deco/tissue panel is made of, or null when the dive
/// has no usable profile analysis.
///
/// Built together from one analysis read so the deco status, the O2
/// exposure and the tissue heat map stay three views of the same instant,
/// even though the diver can show, hide and order Deco Status and Tissue
/// Loading separately.
({
  Widget deco,
  Widget o2,
  Widget? gasSwitches,
  Widget Function({bool expand}) tissue,
})?
_decoPanelCards(
  BuildContext context,
  WidgetRef ref,
  Dive dive,
  DiveDetailAnalysisRetention retention,
) {
  final selectedPointIndex = ref.watch(profileTrackingIndexProvider(dive.id));
  final current = ref
      .watch(
        sourceProfileAnalysisProvider((
          diveId: dive.id,
          sourceId: ref.watch(activeDiveSourceProvider(dive.id)),
        )),
      )
      .valueOrNull;
  // A withheld analysis is a real answer, not a transient blank: it carries
  // the reason the deco cards are missing, so it is usable and retained.
  final isUsable =
      current != null &&
      (current.decoStatuses.isNotEmpty || current.tissueLoadingWithheld);

  // Retain the last usable analysis for THIS dive and fall back to it when the
  // provider momentarily yields null/empty (e.g. a mid-sync empty-profile
  // read), so a single transient null doesn't blink the cards out. A dive that
  // has genuinely never produced an analysis falls through to the null below
  // and correctly shows nothing.
  if (isUsable) retention.retainDecoPanel(dive.id, current);
  final analysis = isUsable ? current : retention.decoPanelFor(dive.id);

  // Don't show if no analysis is, or ever was, available for this dive.
  if (analysis == null ||
      (analysis.decoStatuses.isEmpty && !analysis.tissueLoadingWithheld)) {
    return null;
  }

  // Build "at time" subtitle when a point is selected. The index came from
  // the chart, which draws the active source's series, so it is resolved
  // against that series and never against the merged dive.profile: on a
  // consolidated dive the union has every computer's samples, so the same
  // index lands on a different time (#543).
  final chartProfile =
      ref.watch(activeSourceProfileProvider(dive.id))?.points ?? dive.profile;
  final String? timeSubtitle =
      selectedPointIndex != null && selectedPointIndex < chartProfile.length
      ? context.l10n.diveLog_detail_collapsed_atTime(
          _formatTimestamp(chartProfile[selectedPointIndex].timestamp),
        )
      : null;

  final weeklyOtuAsync = ref.watch(weeklyOtuProvider(dive.id));
  final weeklyOtu = weeklyOtuAsync.valueOrNull;

  final o2Card = CompactO2ToxicityPanel(
    exposure: analysis.o2Exposure,
    selectedPpO2:
        selectedPointIndex != null &&
            selectedPointIndex < analysis.ppO2Curve.length
        ? analysis.ppO2Curve[selectedPointIndex]
        : null,
    selectedCns:
        selectedPointIndex != null &&
            analysis.cnsCurve != null &&
            selectedPointIndex < analysis.cnsCurve!.length
        ? analysis.cnsCurve![selectedPointIndex]
        : null,
    selectedOtu:
        selectedPointIndex != null &&
            analysis.otuCurve != null &&
            selectedPointIndex < analysis.otuCurve!.length
        ? analysis.otuCurve![selectedPointIndex]
        : null,
    subtitle: timeSubtitle,
    weeklyOtu: weeklyOtu,
  );

  // A rebreather loop the analysis could not model (#2593): say why in place
  // of the deco and tissue cards. The O2 card stays; it reads the loop ppO2,
  // not the tissue model.
  if (analysis.tissueLoadingWithheld) {
    Widget withheld(String title) =>
        TissueLoadingWithheldCard(title: title, diveMode: dive.diveMode);
    return (
      deco: withheld(context.l10n.diveLog_detail_section_decoStatus),
      o2: o2Card,
      gasSwitches: null,
      tissue: ({bool expand = false}) =>
          withheld(context.l10n.diveLog_deco_sectionTissueLoading),
    );
  }

  // Use selected point or default to final status
  final index =
      selectedPointIndex != null &&
          selectedPointIndex < analysis.decoStatuses.length
      ? selectedPointIndex
      : analysis.decoStatuses.length - 1;
  final status = analysis.decoStatuses[index];

  Widget buildTissueCard({bool expand = false}) {
    return CompactTissueLoadingCard(
      status: status,
      decoStatuses: analysis.decoStatuses,
      selectedIndex: selectedPointIndex,
      subtitle: timeSubtitle,
      expandVisualization: expand,
      onHeatMapHover: (index) {
        ref.read(profileTrackingIndexProvider(dive.id).notifier).state = index;
      },
      onOpen3dView: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              Dive3dPage(diveId: dive.id, initialMode: SceneKind.tissue),
        ),
      ),
    );
  }

  final decoCard = CompactDecoStatusCard(
    status: status,
    gfSource: analysis.gfSource,
    subtitle: timeSubtitle,
  );

  final efficiency = analysis.gasSwitchEfficiency;
  final gasSwitchCard = efficiency != null && efficiency.evaluated
      ? GasSwitchEfficiencyCard(efficiency: efficiency)
      : null;

  return (
    deco: decoCard,
    o2: o2Card,
    gasSwitches: gasSwitchCard,
    tissue: buildTissueCard,
  );
}
