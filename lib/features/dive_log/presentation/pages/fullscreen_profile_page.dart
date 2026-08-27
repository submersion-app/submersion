import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/readout_card_placement.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_normalization.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/draggable_readout_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_highlight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fullscreen dive review: full-height profile chart with a dive-computer
/// instrument bar, playback, and scrubbing (issues #443, #169).
class FullscreenProfilePage extends ConsumerStatefulWidget {
  final String diveId;

  const FullscreenProfilePage({super.key, required this.diveId});

  @override
  ConsumerState<FullscreenProfilePage> createState() =>
      _FullscreenProfilePageState();
}

class _FullscreenProfilePageState extends ConsumerState<FullscreenProfilePage> {
  late final AppLifecycleListener _lifecycleListener;

  // Captured in initState rather than looked up via `ref` in dispose:
  // Riverpod asserts on `ref.read`/`ref.watch` once the widget is
  // unmounting. The notifier references are plain Dart objects and safe to
  // hold onto; playback's current `isActive` is tracked via [addListener]
  // (StateNotifier's public API) rather than its `@protected` `state`
  // getter.
  late final PlaybackNotifier _playbackNotifier;
  late final StateController<int?> _reviewController;
  late final void Function() _removePlaybackListener;

  /// Whether playback mode was already active for this dive before the
  /// fullscreen page opened. If the page itself activates playback (see
  /// [ProfileTransportControls]), it must deactivate it again on dispose so
  /// the inline dive-detail page doesn't inherit playback mode it never
  /// asked for (and the 25ms ticker doesn't keep running in the background).
  late final bool _wasPlaybackActiveOnEntry;
  bool _isPlaybackActiveNow = false;

  /// Last non-null tooltip rows; the readout card keeps showing these after
  /// the hover ends (sticky values).
  List<TooltipRow>? _readoutRows;

  void _onTooltipData(List<TooltipRow>? rows) {
    if (rows == null || rows.isEmpty) return; // sticky: keep last values
    setState(() => _readoutRows = rows);
  }

  /// Memoized default corner for the readout card, recomputed only when the
  /// profile identity changes (the page rebuilds per playback tick).
  Offset? _autoCorner;
  List<DiveProfilePoint>? _autoCornerProfile;

  /// Default readout-card corner: the chart corner the profile occupies
  /// least (a saved dragged position always overrides this). Strided
  /// sampling keeps this O(200) regardless of profile size.
  Offset _defaultCardCorner(List<DiveProfilePoint> profile) {
    if (!identical(profile, _autoCornerProfile)) {
      _autoCornerProfile = profile;
      final maxT = profile.isEmpty
          ? 0.0
          : profile
                .map((p) => p.timestamp)
                .reduce((a, b) => a > b ? a : b)
                .toDouble();
      final maxD = profile.fold(0.0, (m, p) => m > p.depth ? m : p.depth);
      final stride = profile.length <= 200 ? 1 : profile.length ~/ 200;
      _autoCorner = leastOccupiedReadoutCorner([
        if (maxT > 0 && maxD > 0)
          for (var i = 0; i < profile.length; i += stride)
            Offset(profile[i].timestamp / maxT, profile[i].depth / maxD),
      ]);
    }
    return _autoCorner!;
  }

  @override
  void initState() {
    super.initState();
    _playbackNotifier = ref.read(playbackProvider(widget.diveId).notifier);
    _reviewController = ref.read(profileReviewProvider(widget.diveId).notifier);
    _wasPlaybackActiveOnEntry = ref
        .read(playbackProvider(widget.diveId))
        .isActive;
    _removePlaybackListener = _playbackNotifier.addListener((state) {
      _isPlaybackActiveNow = state.isActive;
    });
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Fullscreen means fullscreen: hide the status and navigation bars so
    // the chart owns the display (#811). Mirrors photo_viewer_page. The
    // call is a no-op on desktop platforms.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    _lifecycleListener = AppLifecycleListener(
      onInactive: () => _playbackNotifier.pause(),
    );
  }

  @override
  void dispose() {
    _removePlaybackListener();
    _lifecycleListener.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    // Riverpod forbids mutating provider state synchronously from a widget
    // lifecycle callback (dispose included), so the cleanup itself is
    // deferred to a microtask, which runs just after the current unmount
    // finishes. Guard with `mounted` in case the whole ProviderScope (and
    // thus these notifiers) is torn down in the same pass, e.g. in tests
    // that never navigate away before disposing the tree.
    final wasActiveOnEntry = _wasPlaybackActiveOnEntry;
    final isActiveNow = _isPlaybackActiveNow;
    final playbackNotifier = _playbackNotifier;
    final reviewController = _reviewController;
    Future.microtask(() {
      if (playbackNotifier.mounted) {
        playbackNotifier.pause();
        if (!wasActiveOnEntry && isActiveNow) {
          playbackNotifier.togglePlaybackMode();
        }
      }
      if (reviewController.mounted) {
        reviewController.state = null;
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Phone layouts give the chart the entire screen: no transport strip
    // below it (#811). shortestSide rather than width so a phone held in
    // landscape -- where vertical room is scarcest -- still counts as one.
    final isPhone = MediaQuery.sizeOf(context).shortestSide < 600;
    // Render from AsyncValue.value so background reloads never flash the UI.
    final diveAsync = ref.watch(diveProvider(widget.diveId));
    final dive = diveAsync.value;
    // The fullscreen chart follows the same active source as the detail
    // page (shared family providers keyed by dive id).
    final activeSourceId = ref.watch(activeDiveSourceProvider(widget.diveId));
    final analysis = ref
        .watch(
          sourceProfileAnalysisProvider((
            diveId: widget.diveId,
            sourceId: activeSourceId,
          )),
        )
        .value;
    final sourceProfiles =
        ref.watch(sourceProfilesProvider(widget.diveId)).value ??
        const <String, SourceProfile>{};
    final dataSources =
        ref.watch(diveDataSourcesProvider(widget.diveId)).value ?? const [];
    final overlayIds = ref.watch(overlaySourcesProvider(widget.diveId));
    final gasSwitches = ref.watch(gasSwitchesProvider(widget.diveId)).value;
    final tankPressures = ref.watch(tankPressuresProvider(widget.diveId)).value;
    // Chart-only: real pressures augmented with linear estimates (#197).
    final estimatedTankPressures = ref
        .watch(estimatedTankPressuresProvider(widget.diveId))
        .value;
    final reviewTimestamp = ref.watch(profileReviewProvider(widget.diveId));
    final selectedFinding = ref.watch(
      selectedSafetyFindingProvider(widget.diveId),
    );
    // Narrow selects (not a full settings watch): this page deliberately
    // avoids rebuilding on unrelated settings writes.
    final safetyReviewEnabled = ref.watch(
      settingsProvider.select((s) => s.safetyReviewEnabled),
    );
    final safetyDisabledRules = ref.watch(
      settingsProvider.select((s) => s.safetyReviewDisabledRules),
    );
    final safetyReview = ref.watch(safetyReviewProvider(widget.diveId)).value;
    final laneFindings = safetyReviewEnabled
        ? chartSafetyFindings(safetyReview, safetyDisabledRules)
        : const <SafetyFinding>[];
    // Gate the highlight on lane membership: with safety review (or the
    // finding's rule) disabled the lane disappears, so an ungated highlight
    // would be stuck on the chart with no UI to clear it.
    final visibleSelectedFinding =
        selectedFinding != null &&
            laneFindings.any((f) => f.id == selectedFinding.id)
        ? selectedFinding
        : null;
    // A finding dismissed elsewhere (callout, detail page, sync) must not
    // stay highlighted: drop a selection with no matching active row.
    ref.listen(safetyReviewProvider(widget.diveId), (previous, next) {
      final review = next.value;
      if (review == null) return;
      final selected = ref.read(selectedSafetyFindingProvider(widget.diveId));
      if (selected == null) return;
      final stillActive = review.findings.any(
        (f) => f.id == selected.id && !f.isDismissed,
      );
      if (!stillActive) {
        ref.read(selectedSafetyFindingProvider(widget.diveId).notifier).state =
            null;
      }
    });
    final showMaxDepthMarker = ref.watch(showMaxDepthMarkerProvider);
    final showPressureThresholdMarkers = ref.watch(
      showPressureThresholdMarkersProvider,
    );
    // Select only the readout-card fields: watching all of settings would
    // rebuild the whole page on every unrelated settings write.
    final settings = ref.watch(
      settingsProvider.select(
        (s) => (
          fullscreenReadoutCardX: s.fullscreenReadoutCardX,
          fullscreenReadoutCardY: s.fullscreenReadoutCardY,
        ),
      ),
    );

    final photoMedia =
        ref.watch(mediaForDiveProvider(widget.diveId)).value ?? const [];

    if (dive == null) {
      final colorScheme = Theme.of(context).colorScheme;
      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: diveAsync.hasError
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: colorScheme.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${diveAsync.error}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : const CircularProgressIndicator(),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final notifier = ref.read(playbackProvider(widget.diveId).notifier);

    // Active source and overlays (mirrors the detail page's wiring).
    final labels = SourceNameLabels(
      unknownComputer: context.l10n.diveLog_sources_unknownComputer,
      manualEntry: context.l10n.diveLog_sources_manualEntry,
      importedFile: context.l10n.diveLog_sources_importedFile,
      editedSuffix: context.l10n.diveLog_sources_editedSuffix,
    );
    final primarySource =
        dataSources.where((s) => s.isPrimary).firstOrNull ??
        dataSources.firstOrNull;
    final activeSource = activeSourceId == null
        ? primarySource
        : dataSources.where((s) => s.id == activeSourceId).firstOrNull ??
              primarySource;
    final activeProfile = activeSource == null
        ? null
        : sourceProfiles[activeSource.id];
    // A metadata-only active source has an entry with no points; the chart
    // then renders its empty-profile placeholder instead of silently
    // falling back to the primary's profile (mixed attribution).
    //
    // Everything overlaid on the chart is derived from THIS series, never
    // from dive.profile: the merged series spans every source, so markers
    // computed against it can report a depth the drawn curve never reaches
    // and photo pins scaled to it drift off the visible span (#1167).
    final chartProfile = (dataSources.length >= 2 && activeProfile != null)
        ? activeProfile.points
        : dive.profile;

    final photoMarkers = chartProfile.isEmpty
        ? const <PhotoChartMarker>[]
        : photoMarkersFromMedia(
            photoMedia,
            maxProfileSeconds: chartProfile.last.timestamp,
          );
    final sourceColorById = <String, Color>{
      for (final (index, s) in dataSources.indexed) s.id: sourceColorAt(index),
    };
    // Overlay ids are session state and can briefly outlive their source
    // rows (e.g. right after a split); skip any stale entries instead of
    // crashing on the lookup.
    final sourceById = {for (final s in dataSources) s.id: s};
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
          ),
    ];

    return Scaffold(
      body: SafeArea(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.space): () {
              final state = ref.read(playbackProvider(widget.diveId));
              if (state.isActive) notifier.togglePlayPause();
            },
            const SingleActivator(LogicalKeyboardKey.arrowLeft):
                notifier.stepBackward,
            const SingleActivator(LogicalKeyboardKey.arrowRight):
                notifier.stepForward,
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.of(context).pop(),
          },
          child: Focus(
            autofocus: true,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Padding(
                        padding: isPhone
                            ? const EdgeInsets.all(4)
                            : const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: DiveProfileChart(
                          profile: chartProfile,
                          overlays: overlays.isEmpty ? null : overlays,
                          activeComputerId: activeProfile?.computerId,
                          diveDuration: dive.effectiveRuntime,
                          maxDepth: dive.maxDepth,
                          // The painted tooltip would clip at the screen edge
                          // (no headroom above the plot in fullscreen); the
                          // draggable readout card renders the data instead.
                          tooltipBelow: true,
                          onTooltipData: _onTooltipData,
                          legendLeading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: context
                                    .l10n
                                    .diveLog_fullscreenProfile_close,
                                visualDensity: VisualDensity.compact,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Text(
                                  context.l10n.diveLog_fullscreenProfile_title(
                                    dive.diveNumber ?? 0,
                                  ),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                            ],
                          ),
                          // Analysis curves: identical wiring to the old
                          // fullscreen call site (dive_detail_page.dart:4946-4990)
                          ceilingCurve: analysis?.ceilingCurve,
                          decoStopCurve: analysis?.decoStopCurve,
                          ascentRates: analysis?.ascentRates,
                          events: analysis?.events,
                          ndlCurve: analysis?.ndlCurve,
                          sacCurve: analysis?.smoothedSacCurve,
                          ppO2Curve: analysis?.ppO2Curve,
                          o2SensorCurves: analysis?.o2SensorCurves,
                          o2CellMvCurves: analysis?.o2CellMvCurves,
                          ppO2FromSensorAverage:
                              analysis?.ppO2FromSensorAverage ?? false,
                          ppN2Curve: analysis?.ppN2Curve,
                          ppHeCurve: analysis?.ppHeCurve,
                          modCurve: analysis?.modCurve,
                          densityCurve: analysis?.densityCurve,
                          gfCurve: analysis?.gfCurve,
                          surfaceGfCurve: analysis?.surfaceGfCurve,
                          meanDepthCurve: analysis?.meanDepthCurve,
                          ttsCurve: analysis?.ttsCurve,
                          cnsCurve: analysis?.cnsCurve,
                          otuCurve: analysis?.otuCurve,
                          tankVolume: dive.tanks
                              .where((t) => t.volume != null && t.volume! > 0)
                              .map((t) => t.volume!)
                              .firstOrNull,
                          sacNormalizationFactor:
                              calculateSacNormalizationFactor(dive, analysis),
                          markers: _calculateMarkers(
                            profile: chartProfile,
                            tanks: dive.tanks,
                            analysis: analysis,
                            tankPressures: tankPressures,
                            showMaxDepth: showMaxDepthMarker,
                            showPressureThresholds:
                                showPressureThresholdMarkers,
                          ),
                          photoMarkers: photoMarkers.isEmpty
                              ? null
                              : photoMarkers,
                          showMaxDepthMarker: showMaxDepthMarker,
                          showPressureThresholdMarkers:
                              showPressureThresholdMarkers,
                          tanks: dive.tanks,
                          tankPressures:
                              estimatedTankPressures?.pressures ??
                              tankPressures,
                          estimatedTankIds:
                              estimatedTankPressures?.estimatedTankIds,
                          gasSwitches: gasSwitches,
                          gasSegments:
                              (dive.tanks.isEmpty || chartProfile.isEmpty)
                              ? null
                              : buildGasUsageSegments(
                                  tanks: dive.tanks,
                                  gasSwitches: gasSwitches ?? const [],
                                  diveDurationSeconds:
                                      chartProfile.last.timestamp,
                                  firstSampleSeconds:
                                      chartProfile.first.timestamp,
                                ),
                          diveDurationSeconds: chartProfile.isEmpty
                              ? null
                              : chartProfile.last.timestamp,
                          highlightedTimestamp: reviewTimestamp,
                          highlightRange: profileHighlightRangeFor(
                            visibleSelectedFinding,
                            Theme.of(context).colorScheme,
                          ),
                          safetyFindings: laneFindings.isEmpty
                              ? null
                              : laneFindings,
                          selectedSafetyFindingId: visibleSelectedFinding?.id,
                          onSafetyFindingTap: (finding) {
                            final selectionNotifier = ref.read(
                              selectedSafetyFindingProvider(
                                widget.diveId,
                              ).notifier,
                            );
                            selectionNotifier.state =
                                selectionNotifier.state?.id == finding.id
                                ? null
                                : finding;
                          },
                          onSafetyFindingDismiss: (finding) =>
                              setSafetyFindingDismissed(
                                ref,
                                finding: finding,
                                dismissed: true,
                              ),
                          onPointSelected: (index) {
                            if (index == null || index >= chartProfile.length) {
                              return;
                            }
                            final timestamp = chartProfile[index].timestamp;
                            ref
                                    .read(
                                      profileReviewProvider(
                                        widget.diveId,
                                      ).notifier,
                                    )
                                    .state =
                                timestamp;
                            // Keep playback in sync so play resumes from here.
                            final playback = ref.read(
                              playbackProvider(widget.diveId),
                            );
                            if (playback.isActive) {
                              notifier.seekTo(timestamp);
                            }
                          },
                        ),
                      ),
                      DraggableReadoutCard(
                        // Re-key on the saved position so a settings load
                        // that lands after first build still seeds the card.
                        key: ValueKey(
                          'readout-card-seed-'
                          '${settings.fullscreenReadoutCardX}-'
                          '${settings.fullscreenReadoutCardY}',
                        ),
                        rows: _readoutRows,
                        placementInsets: isPhone
                            ? const EdgeInsets.fromLTRB(12, 56, 12, 12)
                            : const EdgeInsets.all(12),
                        initialFraction:
                            settings.fullscreenReadoutCardX != null &&
                                settings.fullscreenReadoutCardY != null
                            ? Offset(
                                settings.fullscreenReadoutCardX!,
                                settings.fullscreenReadoutCardY!,
                              )
                            : _defaultCardCorner(chartProfile),
                        onDragEnd: (fraction) => ref
                            .read(settingsProvider.notifier)
                            .setFullscreenReadoutCardPosition(
                              fraction.dx,
                              fraction.dy,
                            ),
                      ),
                    ],
                  ),
                ),
                // Source switching and overlay comparison, mirroring the
                // detail page (management actions stay on the detail page).
                if (dataSources.length >= 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SourceBar(
                      sources: [
                        for (final s in dataSources)
                          SourceBarItem(
                            sourceId: s.id,
                            label: resolveSourceName(
                              s,
                              labels,
                              edited: sourceProfiles[s.id]?.isEdited ?? false,
                            ),
                            color: sourceColorById[s.id] ?? sourceColorAt(0),
                            isActive: s.id == activeSource?.id,
                            isPrimary: s.isPrimary,
                            isOverlaid: overlayIds.contains(s.id),
                            hasProfile:
                                sourceProfiles[s.id]?.points.isNotEmpty ??
                                false,
                          ),
                      ],
                      onActivate: (id) {
                        ref
                                .read(
                                  activeDiveSourceProvider(
                                    widget.diveId,
                                  ).notifier,
                                )
                                .state =
                            id;
                        final current = ref.read(
                          overlaySourcesProvider(widget.diveId),
                        );
                        if (current.contains(id)) {
                          ref
                              .read(
                                overlaySourcesProvider(widget.diveId).notifier,
                              )
                              .state = {...current}
                            ..remove(id);
                        }
                      },
                      onToggleOverlay: (id, overlaid) {
                        final current = ref.read(
                          overlaySourcesProvider(widget.diveId),
                        );
                        ref
                            .read(
                              overlaySourcesProvider(widget.diveId).notifier,
                            )
                            .state = overlaid
                            ? {...current, id}
                            : ({...current}..remove(id));
                      },
                    ),
                  ),
                if (!isPhone)
                  ProfileTransportBar(
                    diveId: widget.diveId,
                    // The same profile the chart renders: the scrub minimap
                    // and seek range must match what is on screen.
                    profile: chartProfile,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Markers to overlay on the profile chart.
  ///
  /// [profile] must be the series the chart is actually drawing (the active
  /// source's points), not `dive.profile`. The analysis these markers are
  /// positioned from is the active source's, so indexing it into the merged
  /// series would place the max-depth flag at another computer's reading
  /// (#1167).
  List<ProfileMarker> _calculateMarkers({
    required List<DiveProfilePoint> profile,
    required List<DiveTank> tanks,
    required ProfileAnalysis? analysis,
    required Map<String, List<TankPressurePoint>>? tankPressures,
    required bool showMaxDepth,
    required bool showPressureThresholds,
  }) {
    final markers = <ProfileMarker>[];
    if (profile.isEmpty) return markers;

    if (showMaxDepth && analysis != null) {
      final maxDepthMarker = ProfileMarkersService.getMaxDepthMarker(
        profile: profile,
        maxDepthTimestamp: analysis.maxDepthTimestamp,
        maxDepth: analysis.maxDepth,
      );
      if (maxDepthMarker != null) markers.add(maxDepthMarker);
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
}
