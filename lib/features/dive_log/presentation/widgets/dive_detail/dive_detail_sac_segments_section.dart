import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_normalization.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_segments_availability.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_analysis_retention.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segments_no_pressure_note.dart';
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
    final currentAsync = ref.watch(
      sourceProfileAnalysisProvider((
        diveId: dive.id,
        sourceId: ref.watch(activeDiveSourceProvider(dive.id)),
      )),
    );
    final current = currentAsync.valueOrNull;
    final isUsable =
        current != null &&
        current.sacSegments != null &&
        current.sacSegments!.isNotEmpty;

    // Retain the last usable analysis for THIS dive and fall back to it when the
    // provider momentarily yields null/empty (e.g. a mid-sync empty-profile
    // read), so a single transient null doesn't blink the card out. A dive that
    // has genuinely never produced segments falls through to the
    // SizedBox.shrink below and correctly shows nothing.
    if (isUsable) retention.retainSacSegments(dive.id, current);
    final analysis = isUsable ? current : retention.sacSegmentsFor(dive.id);

    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final display = ref.watch(gasConsumptionDisplayProvider);
    final lane = ref.watch(sacSegmentsLaneProvider);

    // Get the selected segmentation method
    final selectedMethod = ref.watch(selectedSegmentationProvider);

    // Get segments based on selected method
    final segments = ref.watch(activeSegmentsForDiveProvider(dive));

    // Check availability of different segmentation methods
    final hasGasSwitches =
        ref.watch(hasGasSwitchesProvider(dive.id)).valueOrNull ?? false;

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

    // Use the selected mode's segments, falling back to the (last-good)
    // analysis time segments when that mode yields nothing usable. Treat an
    // empty list like null: activeSegmentsForDiveProvider watches the LIVE
    // profileAnalysisProvider, so a transient non-null/empty-sacSegments
    // emission would otherwise leave `segments` empty and render an empty card
    // even though `analysis` holds a usable last-good list.
    final displaySegments = (segments == null || segments.isEmpty)
        ? analysis.sacSegments!
        : segments;

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

    // Use the top-level normalization function
    final normalizationFactor = calculateSacNormalizationFactor(dive, analysis);

    // Format a segment for the lane the card shows, applying normalization.
    String formatSacValue(double sacBarPerMin, {String? segmentTankId}) {
      final normalizedSac = sacBarPerMin * normalizationFactor;
      final volume = volumeForSegment(segmentTankId);
      if (lane == GasConsumptionLane.rmv && volume != null) {
        return units.formatRmv(normalizedSac * volume);
      }
      return units.formatSac(normalizedSac);
    }

    // Determine which phase the selected point falls into (using original
    // non-overlapping segments for correct timestamp matching). The index is
    // a chart index, so it is resolved against the series the chart draws
    // (#543), see activeSourceProfileProvider.
    final chartProfile =
        ref.watch(activeSourceProfileProvider(dive.id))?.points ?? dive.profile;
    DivePhase? selectedPhase;
    int? selectedSegmentIndex;
    if (selectedPointIndex != null &&
        chartProfile.isNotEmpty &&
        selectedPointIndex < chartProfile.length) {
      final selectedTimestamp = chartProfile[selectedPointIndex].timestamp;
      for (int i = 0; i < displaySegments.length; i++) {
        if (selectedTimestamp >= displaySegments[i].startTimestamp &&
            selectedTimestamp <= displaySegments[i].endTimestamp) {
          selectedSegmentIndex = i;
          selectedPhase = displaySegments[i].phase;
          break;
        }
      }
    }

    // For phase mode, consolidate same-phase segments for compact display.
    // Other modes show segments as-is.
    final isPhaseMode = selectedMethod == SacSegmentationType.depthPhase;
    final renderSegments = isPhaseMode
        ? _consolidateForDisplay(displaySegments)
        : displaySegments;

    // Build collapsed subtitle based on method
    String getSubtitle() {
      final count = renderSegments.length;
      return switch (selectedMethod) {
        SacSegmentationType.timeInterval => '$count segments (5-min intervals)',
        SacSegmentationType.depthBased => '$count depth segments',
        SacSegmentationType.gasSwitch => '$count gas segments',
        SacSegmentationType.depthPhase => '$count phase segments',
      };
    }

    return CollapsibleCardSection(
      title: context.l10n.diveLog_detail_section_sacRateBySegment,
      icon: Icons.air,
      collapsedSubtitle: getSubtitle(),
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
            if (display == GasConsumptionDisplay.both) ...[
              _buildLaneSelector(context, ref, lane),
              const SizedBox(height: 8),
            ],
            // Segmentation method selector
            _buildSegmentationSelector(
              context,
              ref,
              selectedMethod,
              hasGasSwitches,
            ),
            const SizedBox(height: 12),

            // Segment list
            ...renderSegments.asMap().entries.map((entry) {
              final index = entry.key;
              final segment = entry.value;
              final avgDepthDisplay = units.formatDepth(segment.avgDepth);

              // In phase mode, highlight by matching phase name;
              // otherwise match by index into the original list
              final isSelected = isPhaseMode
                  ? segment.phase == selectedPhase
                  : index == selectedSegmentIndex;

              // Get segment label based on type
              final segmentLabel = segment.displayLabel;

              return Container(
                margin: EdgeInsets.only(
                  bottom: index < renderSegments.length - 1 ? 8 : 0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: isSelected
                    ? BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1,
                        ),
                      )
                    : null,
                child: Row(
                  children: [
                    // Phase icon for depth-phase segmentation
                    if (segment.phase != null) ...[
                      Text(
                        segment.phase!.shortLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 4),
                    ],
                    SizedBox(
                      width: segment.phase != null ? 70 : 62,
                      child: Text(
                        segmentLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : null,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: _buildSacBar(
                        context,
                        segment.sacRate,
                        renderSegments
                            .map((s) => s.sacRate)
                            .reduce((a, b) => a > b ? a : b),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: Text(
                        formatSacValue(
                          segment.sacRate,
                          segmentTankId: segment.tankId,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: Text(
                        avgDepthDisplay,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }),
            // Some segment fell back to the pressure lane above: say why.
            if (lane == GasConsumptionLane.rmv &&
                renderSegments.any(
                  (s) => volumeForSegment(s.tankId) == null,
                )) ...[
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
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<GasConsumptionLane>(
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
      ),
    );
  }

  /// Build the segmentation method selector chips
  Widget _buildSegmentationSelector(
    BuildContext context,
    WidgetRef ref,
    SacSegmentationType selected,
    bool hasGasSwitches,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    // Available methods (gas switch only if switches exist)
    final methods = [
      SacSegmentationType.timeInterval,
      if (hasGasSwitches) SacSegmentationType.gasSwitch,
      SacSegmentationType.depthPhase,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: methods.map((method) {
        final isSelected = method == selected;
        return FilterChip(
          label: Text(method.displayName),
          selected: isSelected,
          onSelected: (_) {
            ref.read(selectedSegmentationProvider.notifier).state = method;
          },
          avatar: Icon(
            _getSegmentationIcon(method),
            size: 16,
            color: isSelected ? colorScheme.onSecondaryContainer : null,
          ),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  /// Consolidate phase segments for compact display.
  ///
  /// Groups non-consecutive segments of the same phase (e.g., two Ascent
  /// segments separated by a Safety Stop) into a single display row with
  /// duration-weighted SAC rate and average depth. Preserves chronological
  /// order based on each phase's earliest occurrence.
  List<SacSegment> _consolidateForDisplay(List<SacSegment> segments) {
    if (segments.isEmpty) return segments;

    // Group by phase, preserving chronological order of first occurrence
    final phaseOrder = <DivePhase>[];
    final phaseGroups = <DivePhase, List<SacSegment>>{};

    for (final seg in segments) {
      if (seg.phase == null) return segments;
      final phase = seg.phase!;
      if (!phaseGroups.containsKey(phase)) {
        phaseOrder.add(phase);
        phaseGroups[phase] = [];
      }
      phaseGroups[phase]!.add(seg);
    }

    // If nothing was consolidated, return as-is
    if (phaseOrder.length == segments.length) return segments;

    return phaseOrder.map((phase) {
      final group = phaseGroups[phase]!;
      if (group.length == 1) return group.first;

      // Duration-weighted merge for display
      final totalDuration = group.fold(
        0.0,
        (sum, s) => sum + s.durationMinutes,
      );
      final weightedSac =
          group.fold(0.0, (sum, s) => sum + s.sacRate * s.durationMinutes) /
          totalDuration;
      final weightedAvgDepth =
          group.fold(0.0, (sum, s) => sum + s.avgDepth * s.durationMinutes) /
          totalDuration;
      final totalGasConsumed = group.fold(0.0, (sum, s) => sum + s.gasConsumed);

      return SacSegment(
        startTimestamp: group.first.startTimestamp,
        endTimestamp: group.last.endTimestamp,
        avgDepth: weightedAvgDepth,
        minDepth: group.map((s) => s.minDepth).reduce((a, b) => a < b ? a : b),
        maxDepth: group.map((s) => s.maxDepth).reduce((a, b) => a > b ? a : b),
        sacRate: weightedSac,
        gasConsumed: totalGasConsumed,
        tankId: group.first.tankId,
        tankName: group.first.tankName,
        gasMix: group.first.gasMix,
        phase: phase,
        segmentationType: SacSegmentationType.depthPhase,
      );
    }).toList();
  }

  /// Get icon for segmentation method
  IconData _getSegmentationIcon(SacSegmentationType method) {
    return switch (method) {
      SacSegmentationType.timeInterval => Icons.timer,
      SacSegmentationType.depthBased => Icons.layers,
      SacSegmentationType.gasSwitch => Icons.swap_horiz,
      SacSegmentationType.depthPhase => Icons.trending_down,
    };
  }

  Widget _buildSacBar(BuildContext context, double sacRate, double maxSac) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = maxSac > 0 ? (sacRate / maxSac).clamp(0.0, 1.0) : 0.0;

    // Color based on SAC rate (lower is better)
    Color barColor;
    if (sacRate <= 12) {
      barColor = Colors.green;
    } else if (sacRate <= 18) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: percentage,
        child: Container(
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
