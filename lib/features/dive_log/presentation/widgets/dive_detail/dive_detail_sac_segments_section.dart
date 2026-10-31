import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_normalization.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_rate_display.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_segment_groups.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_segments_availability.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_analysis_retention.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segments_no_pressure_note.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segments_view.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_volume_hint.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Gas consumption by segment card. The same card in the normal section
/// flow and beside Cylinders; it watches the tracking index itself, so hovering
/// the profile chart rebuilds this card rather than the page.
class DiveSacSegmentsSection extends ConsumerWidget {
  const DiveSacSegmentsSection({
    super.key,
    required this.dive,
    required this.retention,
  });

  final Dive dive;
  final DiveDetailAnalysisRetention retention;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPointIndex = ref.watch(profileTrackingIndexProvider(dive.id));
    final sourceKey = (
      diveId: dive.id,
      sourceId: ref.watch(activeDiveSourceProvider(dive.id)),
    );
    final currentAsync = ref.watch(sourceProfileAnalysisProvider(sourceKey));
    final current = currentAsync.valueOrNull;
    final isUsable =
        current != null &&
        current.sacSegments != null &&
        current.sacSegments!.isNotEmpty;

    // Retain the last usable analysis for THIS dive and source and fall back
    // to it when the provider momentarily yields null/empty (e.g. a mid-sync
    // empty-profile read), so a single transient null doesn't blink the card
    // out. A dive that has genuinely never produced segments falls through to
    // the SizedBox.shrink below and correctly shows nothing.
    if (isUsable) retention.retainSacSegments(sourceKey, current);
    final analysis = isUsable ? current : retention.sacSegmentsFor(sourceKey);

    final units = ref.watch(unitFormatterProvider);
    final display = ref.watch(gasConsumptionDisplayProvider);
    final lane = ref.watch(sacSegmentsLaneProvider);

    // Watched ahead of the analysis so they arrive with it instead of after
    // it. `.value` keeps the previous segments through a reload, so a section
    // doesn't drop out for a frame.
    final phaseSegments =
        ref.watch(phaseSegmentsProvider(sourceKey)).value ??
        const <SacSegment>[];
    final gasSegments =
        ref.watch(gasSwitchSegmentsProvider(sourceKey)).value ??
        const <SacSegment>[];

    // Get collapsed state from provider
    final isExpanded = ref.watch(sacSegmentsSectionExpandedProvider);

    // Don't show if no segments are, or ever were, available for this dive
    // (the last-good fallback above keeps a transient null from collapsing it).
    // Per-tank SAC lives on the Cylinders card, which renders regardless. A
    // dive logged with only start and end pressures says why instead of
    // vanishing while its section toggle is on (#2505). It reads `.value`,
    // which keeps the previous analysis through a reload, exactly as the
    // pairing gate in watchHasSacSegments does.
    if (analysis == null ||
        (analysis.sacSegments == null || analysis.sacSegments!.isEmpty)) {
      if (!sacSegmentsLackRecordedPressure(
        currentAsync.value,
        dive,
        // The computer the analysis was scoped to; null on a single source.
        computerId: ref.watch(
          activeSourceProfileProvider(dive.id).select((p) => p?.computerId),
        ),
      )) {
        return const SizedBox.shrink();
      }
      return CollapsibleCardSection(
        title: context.l10n.diveLog_detail_section_sacRateBySegment,
        icon: Icons.air,
        collapsedSubtitle:
            context.l10n.diveLog_detail_sacSegmentsNoPressure_subtitle,
        isExpanded: isExpanded,
        onToggle: (expanded) {
          ref
              .read(collapsibleSectionProvider.notifier)
              .setSacSegmentsExpanded(expanded);
        },
        contentBuilder: (context) => const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SacSegmentsNoPressureNote(),
        ),
      );
    }

    // The profile cursor as a time. The index is a chart index, so it is
    // resolved against the series the chart draws (#543), see
    // activeSourceProfileProvider.
    final chartProfile = watchChartProfile(ref, dive);
    final selectedTimestamp =
        selectedPointIndex != null && selectedPointIndex < chartProfile.length
        ? chartProfile[selectedPointIndex].timestamp
        : null;

    // The volume that converts a segment to L/min. An attributed segment
    // uses its own cylinder (sidemount tanks differ in size, so one shared
    // volume misconverts half the segments, #110); an unattributed one uses
    // the reference cylinder the pressure lane is expressed in. Never another
    // bottle that merely happens to have a size: a stage's volume says
    // nothing about the back gas the segment describes. Null means the
    // segment stays in pressure units.
    double? volumeForSegment(String? segmentTankId) {
      if (segmentTankId == null) return dive.sacReferenceVolume;
      final tank = dive.tanks.where((t) => t.id == segmentTankId).firstOrNull;
      // Its own size, else its matched partner's (issue #3109).
      return tank == null ? null : consumptionVolume(tank, dive.tanks);
    }

    final rates = SacRateDisplay(
      units: units,
      lane: lane,
      normalizationFactor: calculateSacNormalizationFactor(dive, analysis),
      volumeFor: volumeForSegment,
    );

    final timeSegments = analysis.sacSegments!;

    // Some segment fell back to the pressure lane: say why.
    final lacksVolume =
        lane == GasConsumptionLane.rmv &&
        [
          ...timeSegments,
          ...phaseSegments,
          for (final row in gasSectionRows(gasSegments)) ...row.segments,
        ].any((s) => volumeForSegment(s.tankId) == null);

    return CollapsibleCardSection(
      title: context.l10n.diveLog_detail_section_sacRateBySegment,
      icon: Icons.air,
      collapsedSubtitle: context.l10n.diveLog_detail_sacSegments_average(
        rates.formatAverage(timeSegments),
      ),
      isExpanded: isExpanded,
      onToggle: (expanded) {
        ref
            .read(collapsibleSectionProvider.notifier)
            .setSacSegmentsExpanded(expanded);
      },
      contentBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SacSegmentsView(
              key: ValueKey(dive.id),
              timeSegments: timeSegments,
              phaseSegments: phaseSegments,
              gasSegments: gasSegments,
              rates: rates,
              selectedTimestamp: selectedTimestamp,
              laneSelector: display == GasConsumptionDisplay.both
                  ? _buildLaneSelector(context, ref, lane)
                  : null,
            ),
            if (lacksVolume) ...[
              const SizedBox(height: 8),
              SacVolumeHint(
                volumeSymbol: units.volumeSymbol,
                onTap: () => context.push('/dives/${dive.id}/edit'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// SAC | RMV chip for the segment card, shown only when the preference
  /// displays both lanes (a single-lane preference has nothing to choose).
  Widget _buildLaneSelector(
    BuildContext context,
    WidgetRef ref,
    GasConsumptionLane lane,
  ) {
    return SegmentedButton<GasConsumptionLane>(
      segments: [
        ButtonSegment(
          value: GasConsumptionLane.sac,
          label: Text(context.l10n.gasConsumption_sac),
        ),
        ButtonSegment(
          value: GasConsumptionLane.rmv,
          label: Text(context.l10n.gasConsumption_rmv),
        ),
      ],
      selected: {lane},
      showSelectedIcon: false,
      onSelectionChanged: (selection) =>
          ref.read(sacSegmentsLaneOverrideProvider.notifier).state =
              selection.first,
    );
  }
}
