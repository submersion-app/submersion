import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart'
    show calculateSacNormalizationFactor;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_instrument_bar.dart';
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

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _lifecycleListener = AppLifecycleListener(
      onInactive: () =>
          ref.read(playbackProvider(widget.diveId).notifier).pause(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Render from AsyncValue.value so background reloads never flash the UI.
    final dive = ref.watch(diveProvider(widget.diveId)).value;
    final analysis = ref.watch(profileAnalysisProvider(widget.diveId)).value;
    final gasSwitches = ref.watch(gasSwitchesProvider(widget.diveId)).value;
    final tankPressures = ref.watch(tankPressuresProvider(widget.diveId)).value;
    final reviewTimestamp = ref.watch(profileReviewProvider(widget.diveId));
    final showMaxDepthMarker = ref.watch(showMaxDepthMarkerProvider);
    final showPressureThresholdMarkers = ref.watch(
      showPressureThresholdMarkersProvider,
    );

    if (dive == null) {
      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              const Center(child: CircularProgressIndicator()),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    final notifier = ref.read(playbackProvider(widget.diveId).notifier);

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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: DiveProfileChart(
                      profile: dive.profile,
                      diveDuration: dive.effectiveRuntime,
                      maxDepth: dive.maxDepth,
                      legendLeading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip:
                                context.l10n.diveLog_fullscreenProfile_close,
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
                      ascentRates: analysis?.ascentRates,
                      events: analysis?.events,
                      ndlCurve: analysis?.ndlCurve,
                      sacCurve: analysis?.smoothedSacCurve,
                      ppO2Curve: analysis?.ppO2Curve,
                      o2SensorCurves: analysis?.o2SensorCurves,
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
                      sacNormalizationFactor: calculateSacNormalizationFactor(
                        dive,
                        analysis,
                      ),
                      markers: _calculateMarkers(
                        dive: dive,
                        analysis: analysis,
                        tankPressures: tankPressures,
                        showMaxDepth: showMaxDepthMarker,
                        showPressureThresholds: showPressureThresholdMarkers,
                      ),
                      showMaxDepthMarker: showMaxDepthMarker,
                      showPressureThresholdMarkers:
                          showPressureThresholdMarkers,
                      tanks: dive.tanks,
                      tankPressures: tankPressures,
                      gasSwitches: gasSwitches,
                      gasSegments: (dive.tanks.isEmpty || dive.profile.isEmpty)
                          ? null
                          : buildGasUsageSegments(
                              tanks: dive.tanks,
                              gasSwitches: gasSwitches ?? const [],
                              diveDurationSeconds: dive.profile.last.timestamp,
                            ),
                      diveDurationSeconds: dive.profile.isEmpty
                          ? null
                          : dive.profile.last.timestamp,
                      highlightedTimestamp: reviewTimestamp,
                      onPointSelected: (index) {
                        if (index == null || index >= dive.profile.length) {
                          return;
                        }
                        final timestamp = dive.profile[index].timestamp;
                        ref
                                .read(
                                  profileReviewProvider(widget.diveId).notifier,
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
                ),
                ProfileInstrumentBar(
                  diveId: widget.diveId,
                  dive: dive,
                  analysis: analysis,
                  tankPressures: tankPressures,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<ProfileMarker> _calculateMarkers({
    required Dive dive,
    required ProfileAnalysis? analysis,
    required Map<String, List<TankPressurePoint>>? tankPressures,
    required bool showMaxDepth,
    required bool showPressureThresholds,
  }) {
    final markers = <ProfileMarker>[];
    if (dive.profile.isEmpty) return markers;

    if (showMaxDepth && analysis != null) {
      final maxDepthMarker = ProfileMarkersService.getMaxDepthMarker(
        profile: dive.profile,
        maxDepthTimestamp: analysis.maxDepthTimestamp,
        maxDepth: analysis.maxDepth,
      );
      if (maxDepthMarker != null) markers.add(maxDepthMarker);
    }

    if (showPressureThresholds && dive.tanks.isNotEmpty) {
      markers.addAll(
        ProfileMarkersService.getPressureThresholdMarkers(
          profile: dive.profile,
          tanks: dive.tanks,
          tankPressures: tankPressures,
        ),
      );
    }

    return markers;
  }
}
