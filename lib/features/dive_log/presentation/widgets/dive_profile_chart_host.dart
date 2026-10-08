import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart'
    show ProfileAnalysis;
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/presentation/helpers/source_name_labels.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/utils/profile_extent_sync.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_normalization.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cell_divergence_highlight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_highlight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Resolves computerId -> display name for a dive's data sources via the
/// shared [resolveSourceName] fallback chain. Sources without a computerId
/// (manual entries, edited profiles) are skipped: callers key off computerId,
/// so there's nothing to attach the name to.
Map<String, String> computerDisplayNames(
  BuildContext context,
  List<DiveDataSource> dataSources,
) {
  final labels = sourceNameLabelsFor(context);
  return {
    for (final source in dataSources)
      if (source.computerId != null)
        source.computerId!: resolveSourceName(source, labels),
  };
}

/// The chart's max-depth and pressure-threshold pins, for the series actually
/// drawn.
List<ProfileMarker> profileChartMarkers({
  required List<DiveProfilePoint> profile,
  required List<DiveTank> tanks,
  required ProfileAnalysis? analysis,
  required bool showMaxDepth,
  required bool showPressureThresholds,
  Map<String, List<TankPressurePoint>>? tankPressures,
}) {
  final markers = <ProfileMarker>[];

  if (profile.isEmpty) return markers;

  if (showMaxDepth && analysis != null) {
    final maxDepthMarker = ProfileMarkersService.getMaxDepthMarker(
      profile: profile,
      maxDepthTimestamp: analysis.maxDepthTimestamp,
      maxDepth: analysis.maxDepth,
    );
    if (maxDepthMarker != null) {
      markers.add(maxDepthMarker);
    }
  }

  if (showPressureThresholds && tanks.isNotEmpty) {
    markers.addAll(
      ProfileMarkersService.getPressureThresholdMarkers(
        profile: profile,
        tanks: tanks,
        tankPressures: tankPressures,
      ),
    );
  }

  return markers;
}

/// A fully wired [DiveProfileChart] for [dive].
///
/// Every surface that shows a dive's profile draws the same chart with the
/// same inputs: the dive detail page, and the latest-dive slot on the home
/// tab. Those inputs are ~40 derived values pulled from a dozen providers
/// (per-source profiles and their analyses, overlays, markers, photo pins,
/// tank pressures, gas segments, safety findings, range and playback state),
/// and hand-copying that list per call site is how two surfaces silently
/// stop agreeing about the same dive. This is the one copy.
///
/// Only genuinely host-specific concerns stay parameters. Everything else,
/// including the legend's metric toggles ([profileLegendProvider] is a single
/// app-wide notifier), is shared state, so turning on a curve in dive details
/// turns it on everywhere the chart is drawn.
class DiveProfileChartHost extends ConsumerWidget {
  const DiveProfileChartHost({
    super.key,
    required this.dive,
    this.exportKey,
    this.legendLeading,
    this.tooltipPresentation = TooltipPresentation.inChart,
    this.onTooltipData,
    this.onSafetyFindingDetails,
  });

  /// The hydrated dive: tanks and profile samples included. A dive loaded for
  /// a list view carries neither, and would draw an empty chart.
  final Dive dive;

  /// Repaint boundary key for "export profile as image".
  final GlobalKey? exportKey;

  /// Rendered at the head of the legend row (the fullscreen page's close
  /// button and title).
  final Widget? legendLeading;

  /// Which of the three mutually exclusive ways the hosted chart shows the
  /// touched/hovered sample's readout. See [TooltipPresentation].
  final TooltipPresentation tooltipPresentation;

  final void Function(List<TooltipRow>? rows)? onTooltipData;

  /// "Show me the details" on a safety finding's callout. Null hides the
  /// action, which is right wherever the safety section is not on screen to
  /// scroll to.
  final void Function(SafetyFinding finding)? onSafetyFindingDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diveId = dive.id;

    // Every async chart input below is read through the built-in
    // AsyncValue.value, which keeps the previous value while a provider
    // reloads. The valueOrNull polyfill returns null during a reload, and
    // these providers reload behind any detail change tick (the first-view
    // safety review write included): the chart would drop its overlays and
    // estimated pressure series for a frame, then draw them again (#1468).
    final activeSourceId = ref.watch(activeDiveSourceProvider(diveId));
    final analysis = ref
        .watch(
          sourceProfileAnalysisProvider((
            diveId: diveId,
            sourceId: activeSourceId,
          )),
        )
        .value;

    final showMaxDepthMarker = ref.watch(showMaxDepthMarkerProvider);
    final showPressureThresholdMarkers = ref.watch(
      showPressureThresholdMarkersProvider,
    );

    final gasSwitches = ref.watch(gasSwitchesProvider(diveId)).value;

    // Cell divergence bands (condition phase 2). .value keeps the previous
    // summary while the provider reloads behind a detail tick, like the
    // inputs above.
    final sensorSummary = ref.watch(diveSensorSummaryProvider(diveId)).value;

    // Per-tank pressures, augmented for the chart only with linear estimates
    // between the samples a computer actually reported (#197).
    final tankPressures = ref
        .watch(activeSourceTankPressuresProvider(diveId))
        .value;
    final estimatedTankPressures = ref
        .watch(estimatedTankPressuresProvider(diveId))
        .value;

    final rangeState = ref.watch(rangeSelectionProvider(diveId));

    final sourceProfiles =
        ref.watch(sourceProfilesProvider(diveId)).value ??
        const <String, SourceProfile>{};
    final dataSources =
        ref.watch(diveDataSourcesProvider(diveId)).value ??
        const <DiveDataSource>[];
    final computerNames = computerDisplayNames(context, dataSources);
    final labels = sourceNameLabelsFor(context);

    // Per-source rendering exists because two computers recording one dive
    // disagree sample by sample (#543); the halves of a split dive a Combine
    // stitched together are not that, and drawing one of those would hide the
    // rest of the dive (#1451).
    final isMultiSource = usesPerSourceRendering(
      dataSources,
      sourceProfiles.values,
    );

    final overlayIds = ref.watch(overlaySourcesProvider(diveId));

    final primarySource =
        dataSources.where((s) => s.isPrimary).firstOrNull ??
        dataSources.firstOrNull;
    final activeSource = activeSourceId == null
        ? primarySource
        : dataSources.where((s) => s.id == activeSourceId).firstOrNull ??
              primarySource;

    // Stable color per source, assigned by data-source order (never changes
    // as overlays toggle).
    final sourceColorById = <String, Color>{
      for (final (index, s) in dataSources.indexed) s.id: sourceColorAt(index),
    };

    // Per-computer color, so tank rings can mark which computer a tank
    // belongs to when two computers logged tanks sharing the same gas mix
    // (otherwise identical swatches).
    final computerColorById = <String, Color>{
      for (final (index, s) in dataSources.indexed)
        if (s.computerId != null) s.computerId!: sourceColorAt(index),
    };
    final tankSourceColors = isMultiSource
        ? <String, Color>{
            for (final t in dive.tanks)
              if (t.computerId != null &&
                  computerColorById[t.computerId] != null)
                t.id: computerColorById[t.computerId]!,
          }
        : null;

    // The chart's main series: the active source's own points on a
    // multi-source dive; dive.profile otherwise (identical for the primary).
    // Attribution (activeComputerId) reads the SAME result, so the drawn
    // points and the computer they are credited to can never disagree.
    //
    // A metadata-only active source has an entry with no points; the chart
    // then renders its empty-profile placeholder instead of silently falling
    // back to the primary's profile (mixed attribution).
    //
    // Everything overlaid on the chart is derived from THIS series, never
    // from dive.profile: the merged series spans every source, so markers
    // computed against it can report a depth the drawn curve never reaches
    // and a range extent that runs past its end (#1167).
    final resolvedActive = ref.watch(activeSourceProfileProvider(diveId));
    // Attribution follows the drawn series, because activeComputerId is what
    // gates every per-computer layer (tank pressure traces, events).
    //
    // A non-null resolvedActive means one source's bucket is drawn, so that
    // source owns the series. Null means the merged dive.profile is drawn,
    // and then it depends on how many sources went into the union: on a
    // single-source dive the union IS that source, so it still owns it, but
    // on a Combine's sequential halves the union spans several computers and
    // none of them owns it (#1451). Naming one there hid the other half's
    // tank pressures and events while its depth samples stayed on the chart.
    final activeProfile =
        resolvedActive ??
        (dataSources.length == 1 ? sourceProfiles[dataSources.first.id] : null);
    final chartProfile = resolvedActive?.points ?? dive.profile;

    keepProfileExtentsOnDrawnSeries(
      context,
      ref,
      diveId: diveId,
      chartProfile: chartProfile,
    );

    final markers = profileChartMarkers(
      profile: chartProfile,
      tanks: dive.tanks,
      analysis: analysis,
      showMaxDepth: showMaxDepthMarker,
      showPressureThresholds: showPressureThresholdMarkers,
      tankPressures: tankPressures,
    );

    final photoMedia =
        ref.watch(mediaForDiveProvider(diveId)).value ?? const [];
    final photoMarkers = chartProfile.isEmpty
        ? const <PhotoChartMarker>[]
        : photoMarkersFromMedia(
            photoMedia,
            maxProfileSeconds: chartProfile.last.timestamp,
          );

    // Overlay ids are session state and can briefly outlive their source rows
    // (e.g. right after a split); skip any stale entries instead of crashing
    // on the lookup.
    final sourceById = {for (final s in dataSources) s.id: s};
    // Plan-vs-actual: the planned profile this dive was converted from,
    // ghosted next to the actual logged profile.
    final plannedOverlay = ref
        .watch(plannedProfileOverlayProvider(diveId))
        .value;
    final overlays = <ChartSourceOverlay>[
      for (final id in overlayIds)
        if (id != activeSource?.id &&
            sourceProfiles[id] != null &&
            sourceById[id] != null)
          ChartSourceOverlay(
            sourceId: id,
            name: resolveSourceName(
              sourceById[id]!,
              labels,
              edited: sourceProfiles[id]!.isEdited,
            ),
            color: sourceColorById[id] ?? sourceColorAt(0),
            computerId: sourceProfiles[id]!.computerId,
            points: sourceProfiles[id]!.points,
            // This source's own computed analysis, for overlay curves with no
            // raw per-point device field to fall back on. Cached by the
            // (diveId, sourceId) family key, so toggling the eye icon doesn't
            // re-run Buhlmann.
            analysis: ref
                .watch(
                  sourceProfileAnalysisProvider((diveId: diveId, sourceId: id)),
                )
                .value,
          ),
      ?plannedOverlay,
    ];

    final trackingIndex = ref.watch(profileTrackingIndexProvider(diveId));
    final selectedFinding = ref.watch(selectedSafetyFindingProvider(diveId));
    final safetyReview = ref.watch(safetyReviewProvider(diveId)).value;
    final appSettings = ref.watch(settingsProvider);
    final laneFindings = appSettings.safetyReviewEnabled
        ? chartSafetyFindings(
            safetyReview,
            appSettings.safetyReviewDisabledRules,
          )
        : const <SafetyFinding>[];
    // Gate the highlight on lane membership: with safety review (or the
    // finding's rule) disabled neither the lane nor the section renders, so an
    // ungated highlight would be stuck on the chart with no UI to clear it.
    final visibleSelectedFinding =
        selectedFinding != null &&
            laneFindings.any((f) => f.id == selectedFinding.id)
        ? selectedFinding
        : null;

    return MouseRegion(
      onExit: (_) {
        ref.read(profileTrackingIndexProvider(diveId).notifier).state = null;
      },
      child: DiveProfileChart(
        exportKey: exportKey,
        profile: chartProfile,
        overlays: overlays.isEmpty ? null : overlays,
        activeComputerId: activeProfile?.computerId,
        diveDuration: dive.effectiveRuntime,
        maxDepth: dive.maxDepth,
        legendLeading: legendLeading,
        tooltipPresentation: tooltipPresentation,
        onTooltipData: onTooltipData,
        ceilingCurve: analysis?.ceilingCurve,
        decoStopCurve: analysis?.decoStopCurve,
        ascentRates: analysis?.ascentRates,
        events: analysis?.events,
        ndlCurve: analysis?.ndlCurve,
        sacCurve: analysis?.smoothedSacCurve,
        ppO2Curve: analysis?.ppO2Curve,
        o2SensorCurves: analysis?.o2SensorCurves,
        o2CellMvCurves: analysis?.o2CellMvCurves,
        ppO2FromSensorAverage: analysis?.ppO2FromSensorAverage ?? false,
        ppN2Curve: analysis?.ppN2Curve,
        ppHeCurve: analysis?.ppHeCurve,
        modCurve: analysis?.modCurve,
        densityCurve: analysis?.densityCurve,
        gfCurve: analysis?.gfCurve,
        surfaceGfCurve: analysis?.surfaceGfCurve,
        meanDepthCurve: analysis?.meanDepthCurve,
        ttsCurve: analysis?.ttsCurve,
        gasSwitchEfficiency: analysis?.gasSwitchEfficiency,
        gtrCurve: analysis?.gtrCurve,
        cnsCurve: analysis?.cnsCurve,
        otuCurve: analysis?.otuCurve,
        tankVolume: dive.tanks
            .where((t) => t.volume != null && t.volume! > 0)
            .map((t) => t.volume!)
            .firstOrNull,
        sacNormalizationFactor: calculateSacNormalizationFactor(dive, analysis),
        markers: markers,
        photoMarkers: photoMarkers.isEmpty ? null : photoMarkers,
        showMaxDepthMarker: showMaxDepthMarker,
        showPressureThresholdMarkers: showPressureThresholdMarkers,
        tanks: dive.tanks,
        tankPressures: estimatedTankPressures?.pressures ?? tankPressures,
        estimatedTankIds: estimatedTankPressures?.estimatedTankIds,
        tankSourceColors: tankSourceColors,
        gasSwitches: gasSwitches,
        gasSegments: (dive.tanks.isEmpty || chartProfile.isEmpty)
            ? null
            : buildGasUsageSegments(
                tanks: dive.tanks,
                gasSwitches: gasSwitches ?? const [],
                diveDurationSeconds: chartProfile.last.timestamp,
                firstSampleSeconds: chartProfile.first.timestamp,
              ),
        diveDurationSeconds: chartProfile.isEmpty
            ? null
            : chartProfile.last.timestamp,
        computerNames: computerNames,
        // No playbackTimestamp: the inline chart is never on screen while
        // playback runs. Playback is only ever activated by
        // ProfileTransportControls, which exists solely inside
        // FullscreenProfilePage, and that page is pushed onto the ROOT
        // navigator, so it covers this chart completely. Feeding the cursor
        // from here meant watching the 25ms ticker and re-running this whole
        // build ~31 times a second behind an opaque page (#2231): a covered
        // route skips layout and paint, but its elements stay in the tree and
        // still rebuild. The fullscreen chart draws its own playback cursor
        // from highlightedTimestamp, which ProfileTransportControls keeps in
        // sync with the ticker.
        //
        // DiveProfileChart.playbackTimestamp stays a supported input, covered
        // by dive_profile_chart_test.dart, for whenever inline playback
        // returns (c4e70ae1814 removed the entry point "until the
        // functionality can be more thought-out"). Whatever revives it needs
        // to scope the subscription to the cursor rather than to the host.
        //
        // playbackIsPlaying is likewise not forwarded here for the same
        // reason: there is no playback ticker subscription on this host to
        // read it from any more (issue #2228 follow-up forwarded it briefly
        // before #2231 removed the underlying watch).
        highlightedTimestamp:
            trackingIndex != null && trackingIndex < chartProfile.length
            ? chartProfile[trackingIndex].timestamp
            : null,
        highlightRange: profileHighlightRangeFor(
          visibleSelectedFinding,
          Theme.of(context).colorScheme,
        ),
        secondaryRanges: cellDivergenceHighlightRanges(
          sensorSummary,
          Theme.of(context).colorScheme,
        ),
        safetyFindings: laneFindings.isEmpty ? null : laneFindings,
        selectedSafetyFindingId: visibleSelectedFinding?.id,
        onSafetyFindingTap: (finding) {
          final notifier = ref.read(
            selectedSafetyFindingProvider(diveId).notifier,
          );
          notifier.state = notifier.state?.id == finding.id ? null : finding;
        },
        onSafetyFindingDismiss: (finding) =>
            setSafetyFindingDismissed(ref, finding: finding, dismissed: true),
        onSafetyFindingDetails: onSafetyFindingDetails,
        // Range handles are drawn by the chart itself so they land on the
        // plot rect at any zoom (#1579).
        rangeSelection: rangeState.isEnabled
            ? (
                startSeconds: rangeState.startTimestamp ?? 0,
                endSeconds: rangeState.endTimestamp ?? rangeState.maxTimestamp,
                maxSeconds: rangeState.maxTimestamp,
              )
            : null,
        onRangeChanged: (start, end) => ref
            .read(rangeSelectionProvider(diveId).notifier)
            .setRange(start, end),
        onPointSelected: (index) {
          ref.read(profileTrackingIndexProvider(diveId).notifier).state = index;
        },
      ),
    );
  }
}
