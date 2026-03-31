import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

part 'profile_legend_provider.g.dart';

/// Immutable state for dive profile chart legend toggles.
///
/// Separates "primary" toggles (commonly used, always visible) from
/// "secondary" toggles (less common, shown in popover menu).
@immutable
class ProfileLegendState {
  // Right Y-axis metric selection
  final ProfileRightAxisMetric? rightAxisMetric;

  // Whether the user explicitly hid the right axis (chose "None")
  final bool rightAxisHidden;

  // Primary toggles (always visible in legend)
  final bool showTemperature;
  final bool showPressure;
  final bool showCeiling;

  // Secondary toggles (shown in "More" popover)
  final bool showHeartRate;
  final bool showSac;
  final bool showAscentRateColors;
  final bool showEvents;
  final bool showMaxDepthMarker;
  final bool showPressureMarkers;
  final bool showGasSwitchMarkers;

  // Advanced decompression/gas toggles
  final bool showNdl;
  final bool showPpO2;
  final bool showPpN2;
  final bool showPpHe;
  final bool showMod;
  final bool showDensity;
  final bool showGf;
  final bool showSurfaceGf;
  final bool showMeanDepth;
  final bool showTts;
  final bool showCns;
  final bool showOtu;

  // Per-metric data source preferences (session overrides)
  final MetricDataSource ndlSource;
  final MetricDataSource ceilingSource;
  final MetricDataSource ttsSource;
  final MetricDataSource cnsSource;

  // Per-tank pressure visibility (keyed by tank ID)
  final Map<String, bool> showTankPressure;

  // Collapsible section expanded/collapsed state (session-only)
  final Map<String, bool> sectionExpanded;

  const ProfileLegendState({
    this.rightAxisMetric,
    this.rightAxisHidden = false,
    this.showTemperature = true,
    this.showPressure = false,
    this.showCeiling = true,
    this.showHeartRate = false,
    this.showSac = false,
    this.showAscentRateColors = true,
    this.showEvents = true,
    this.showMaxDepthMarker = true,
    this.showPressureMarkers = true,
    this.showGasSwitchMarkers = true,
    this.showNdl = false,
    this.showPpO2 = false,
    this.showPpN2 = false,
    this.showPpHe = false,
    this.showMod = false,
    this.showDensity = false,
    this.showGf = false,
    this.showSurfaceGf = false,
    this.showMeanDepth = false,
    this.showTts = false,
    this.showCns = false,
    this.showOtu = false,
    this.ndlSource = MetricDataSource.calculated,
    this.ceilingSource = MetricDataSource.calculated,
    this.ttsSource = MetricDataSource.calculated,
    this.cnsSource = MetricDataSource.calculated,
    this.showTankPressure = const {},
    this.sectionExpanded = const {
      'overlays': true,
      'decompression': true,
      'markers': false,
      'tanks': true,
      'gasAnalysis': false,
      'other': false,
      'tankPressures': true,
    },
  });

  /// Count of active secondary toggles (for badge display)
  int get activeSecondaryCount {
    var count = 0;
    if (showCeiling) count++;
    if (showHeartRate) count++;
    if (showSac) count++;
    if (showAscentRateColors) count++;
    if (showMaxDepthMarker) count++;
    if (showPressureMarkers) count++;
    if (showGasSwitchMarkers) count++;
    if (showNdl) count++;
    if (showPpO2) count++;
    if (showPpN2) count++;
    if (showPpHe) count++;
    if (showMod) count++;
    if (showDensity) count++;
    if (showGf) count++;
    if (showSurfaceGf) count++;
    if (showMeanDepth) count++;
    if (showTts) count++;
    if (showCns) count++;
    if (showOtu) count++;
    count += showTankPressure.values.where((v) => v).length;
    return count;
  }

  /// Whether any secondary toggle is active
  bool get hasActiveSecondary => activeSecondaryCount > 0;

  ProfileLegendState copyWith({
    ProfileRightAxisMetric? rightAxisMetric,
    bool clearRightAxisMetric = false,
    bool? rightAxisHidden,
    bool? showTemperature,
    bool? showPressure,
    bool? showCeiling,
    bool? showHeartRate,
    bool? showSac,
    bool? showAscentRateColors,
    bool? showEvents,
    bool? showMaxDepthMarker,
    bool? showPressureMarkers,
    bool? showGasSwitchMarkers,
    bool? showNdl,
    bool? showPpO2,
    bool? showPpN2,
    bool? showPpHe,
    bool? showMod,
    bool? showDensity,
    bool? showGf,
    bool? showSurfaceGf,
    bool? showMeanDepth,
    bool? showTts,
    bool? showCns,
    bool? showOtu,
    MetricDataSource? ndlSource,
    MetricDataSource? ceilingSource,
    MetricDataSource? ttsSource,
    MetricDataSource? cnsSource,
    Map<String, bool>? showTankPressure,
    Map<String, bool>? sectionExpanded,
  }) {
    return ProfileLegendState(
      rightAxisMetric: clearRightAxisMetric
          ? null
          : (rightAxisMetric ?? this.rightAxisMetric),
      rightAxisHidden: rightAxisHidden ?? this.rightAxisHidden,
      showTemperature: showTemperature ?? this.showTemperature,
      showPressure: showPressure ?? this.showPressure,
      showCeiling: showCeiling ?? this.showCeiling,
      showHeartRate: showHeartRate ?? this.showHeartRate,
      showSac: showSac ?? this.showSac,
      showAscentRateColors: showAscentRateColors ?? this.showAscentRateColors,
      showEvents: showEvents ?? this.showEvents,
      showMaxDepthMarker: showMaxDepthMarker ?? this.showMaxDepthMarker,
      showPressureMarkers: showPressureMarkers ?? this.showPressureMarkers,
      showGasSwitchMarkers: showGasSwitchMarkers ?? this.showGasSwitchMarkers,
      showNdl: showNdl ?? this.showNdl,
      showPpO2: showPpO2 ?? this.showPpO2,
      showPpN2: showPpN2 ?? this.showPpN2,
      showPpHe: showPpHe ?? this.showPpHe,
      showMod: showMod ?? this.showMod,
      showDensity: showDensity ?? this.showDensity,
      showGf: showGf ?? this.showGf,
      showSurfaceGf: showSurfaceGf ?? this.showSurfaceGf,
      showMeanDepth: showMeanDepth ?? this.showMeanDepth,
      showTts: showTts ?? this.showTts,
      showCns: showCns ?? this.showCns,
      showOtu: showOtu ?? this.showOtu,
      ndlSource: ndlSource ?? this.ndlSource,
      ceilingSource: ceilingSource ?? this.ceilingSource,
      ttsSource: ttsSource ?? this.ttsSource,
      cnsSource: cnsSource ?? this.cnsSource,
      showTankPressure: showTankPressure ?? this.showTankPressure,
      sectionExpanded: sectionExpanded ?? this.sectionExpanded,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileLegendState &&
          runtimeType == other.runtimeType &&
          rightAxisMetric == other.rightAxisMetric &&
          rightAxisHidden == other.rightAxisHidden &&
          showTemperature == other.showTemperature &&
          showPressure == other.showPressure &&
          showCeiling == other.showCeiling &&
          showHeartRate == other.showHeartRate &&
          showSac == other.showSac &&
          showAscentRateColors == other.showAscentRateColors &&
          showEvents == other.showEvents &&
          showMaxDepthMarker == other.showMaxDepthMarker &&
          showPressureMarkers == other.showPressureMarkers &&
          showGasSwitchMarkers == other.showGasSwitchMarkers &&
          showNdl == other.showNdl &&
          showPpO2 == other.showPpO2 &&
          showPpN2 == other.showPpN2 &&
          showPpHe == other.showPpHe &&
          showMod == other.showMod &&
          showDensity == other.showDensity &&
          showGf == other.showGf &&
          showSurfaceGf == other.showSurfaceGf &&
          showMeanDepth == other.showMeanDepth &&
          showTts == other.showTts &&
          showCns == other.showCns &&
          showOtu == other.showOtu &&
          ndlSource == other.ndlSource &&
          ceilingSource == other.ceilingSource &&
          ttsSource == other.ttsSource &&
          cnsSource == other.cnsSource &&
          mapEquals(showTankPressure, other.showTankPressure) &&
          mapEquals(sectionExpanded, other.sectionExpanded);

  @override
  int get hashCode => Object.hashAll([
    rightAxisMetric,
    rightAxisHidden,
    showTemperature,
    showPressure,
    showCeiling,
    showHeartRate,
    showSac,
    showAscentRateColors,
    showEvents,
    showMaxDepthMarker,
    showPressureMarkers,
    showGasSwitchMarkers,
    showNdl,
    showPpO2,
    showPpN2,
    showPpHe,
    showMod,
    showDensity,
    showGf,
    showSurfaceGf,
    showMeanDepth,
    showTts,
    showCns,
    showOtu,
    ndlSource,
    ceilingSource,
    ttsSource,
    cnsSource,
    ...showTankPressure.entries,
    ...sectionExpanded.entries,
  ]);
}

/// Provider for managing dive profile legend toggle state.
///
/// Usage:
/// ```dart
/// final legendState = ref.watch(profileLegendProvider);
/// final legendNotifier = ref.read(profileLegendProvider.notifier);
/// legendNotifier.toggleTemperature();
/// ```
@riverpod
class ProfileLegend extends _$ProfileLegend {
  @override
  ProfileLegendState build() {
    // Initialize from user settings
    final settings = ref.watch(settingsProvider);
    return ProfileLegendState(
      // rightAxisMetric is null initially - uses setting default via fallback
      showTemperature: settings.defaultShowTemperature,
      showPressure: settings.defaultShowPressure,
      showCeiling: settings.showCeilingOnProfile,
      showHeartRate: settings.defaultShowHeartRate,
      showSac: settings.defaultShowSac,
      showAscentRateColors: settings.showAscentRateColors,
      showEvents: settings.defaultShowEvents,
      showMaxDepthMarker: settings.showMaxDepthMarker,
      showPressureMarkers: settings.showPressureThresholdMarkers,
      showGasSwitchMarkers: settings.defaultShowGasSwitchMarkers,
      showNdl: settings.showNdlOnProfile,
      showPpO2: settings.defaultShowPpO2,
      showPpN2: settings.defaultShowPpN2,
      showPpHe: settings.defaultShowPpHe,
      showMod: false, // MOD not in settings yet
      showDensity: settings.defaultShowGasDensity,
      showGf: settings.defaultShowGf,
      showSurfaceGf: settings.defaultShowSurfaceGf,
      showMeanDepth: settings.defaultShowMeanDepth,
      showTts: settings.defaultShowTts,
      showCns: settings.defaultShowCns,
      showOtu: settings.defaultShowOtu,
      ndlSource: settings.defaultNdlSource,
      ceilingSource: settings.defaultCeilingSource,
      ttsSource: settings.defaultTtsSource,
      cnsSource: settings.defaultCnsSource,
    );
  }

  /// Set the right axis metric for this session (also un-hides it)
  void setRightAxisMetric(ProfileRightAxisMetric? metric) {
    if (metric == null) {
      state = state.copyWith(clearRightAxisMetric: true);
    } else {
      state = state.copyWith(rightAxisMetric: metric, rightAxisHidden: false);
    }
  }

  /// Explicitly hide the right axis ("None" selection)
  void hideRightAxis() {
    state = state.copyWith(rightAxisHidden: true, clearRightAxisMetric: true);
  }

  /// Get the effective right axis metric (session override or settings default).
  /// Returns null when the user has explicitly chosen "None".
  ProfileRightAxisMetric? getEffectiveRightAxisMetric() {
    if (state.rightAxisHidden) return null;
    return state.rightAxisMetric ??
        ref.read(settingsProvider).defaultRightAxisMetric;
  }

  // Primary toggle methods
  void toggleTemperature() {
    state = state.copyWith(showTemperature: !state.showTemperature);
  }

  void togglePressure() {
    state = state.copyWith(showPressure: !state.showPressure);
  }

  void toggleCeiling() {
    state = state.copyWith(showCeiling: !state.showCeiling);
  }

  // Secondary toggle methods
  void toggleHeartRate() {
    state = state.copyWith(showHeartRate: !state.showHeartRate);
  }

  void toggleSac() {
    state = state.copyWith(showSac: !state.showSac);
  }

  void toggleAscentRateColors() {
    state = state.copyWith(showAscentRateColors: !state.showAscentRateColors);
  }

  void toggleEvents() {
    state = state.copyWith(showEvents: !state.showEvents);
  }

  void toggleMaxDepthMarker() {
    state = state.copyWith(showMaxDepthMarker: !state.showMaxDepthMarker);
  }

  void togglePressureMarkers() {
    state = state.copyWith(showPressureMarkers: !state.showPressureMarkers);
  }

  void toggleGasSwitchMarkers() {
    state = state.copyWith(showGasSwitchMarkers: !state.showGasSwitchMarkers);
  }

  // Advanced decompression/gas toggle methods
  void toggleNdl() {
    state = state.copyWith(showNdl: !state.showNdl);
  }

  void togglePpO2() {
    state = state.copyWith(showPpO2: !state.showPpO2);
  }

  void togglePpN2() {
    state = state.copyWith(showPpN2: !state.showPpN2);
  }

  void togglePpHe() {
    state = state.copyWith(showPpHe: !state.showPpHe);
  }

  void toggleMod() {
    state = state.copyWith(showMod: !state.showMod);
  }

  void toggleDensity() {
    state = state.copyWith(showDensity: !state.showDensity);
  }

  void toggleGf() {
    state = state.copyWith(showGf: !state.showGf);
  }

  void toggleSurfaceGf() {
    state = state.copyWith(showSurfaceGf: !state.showSurfaceGf);
  }

  void toggleMeanDepth() {
    state = state.copyWith(showMeanDepth: !state.showMeanDepth);
  }

  void toggleTts() {
    state = state.copyWith(showTts: !state.showTts);
  }

  void toggleCns() {
    state = state.copyWith(showCns: !state.showCns);
  }

  void toggleOtu() {
    state = state.copyWith(showOtu: !state.showOtu);
  }

  // Data source set methods (for SegmentedButton)
  void setCeilingSource(MetricDataSource source) {
    state = state.copyWith(ceilingSource: source);
  }

  void setNdlSource(MetricDataSource source) {
    state = state.copyWith(ndlSource: source);
  }

  void setTtsSource(MetricDataSource source) {
    state = state.copyWith(ttsSource: source);
  }

  void setCnsSource(MetricDataSource source) {
    state = state.copyWith(cnsSource: source);
  }

  // Section expand/collapse
  void toggleSection(String sectionKey) {
    final current = state.sectionExpanded[sectionKey] ?? false;
    state = state.copyWith(
      sectionExpanded: {...state.sectionExpanded, sectionKey: !current},
    );
  }

  /// Set a section's expanded state directly (avoids toggle desync risk)
  void setSectionExpanded(String sectionKey, bool expanded) {
    state = state.copyWith(
      sectionExpanded: {...state.sectionExpanded, sectionKey: expanded},
    );
  }

  /// Toggle visibility for a specific tank's pressure line
  void toggleTankPressure(String tankId) {
    final current = state.showTankPressure[tankId] ?? true;
    state = state.copyWith(
      showTankPressure: {...state.showTankPressure, tankId: !current},
    );
  }

  /// Initialize tank pressure visibility for tanks that don't have state yet
  void initializeTankPressures(List<String> tankIds) {
    final updated = Map<String, bool>.from(state.showTankPressure);
    var hasChanges = false;

    for (final tankId in tankIds) {
      if (!updated.containsKey(tankId)) {
        updated[tankId] = true; // Default to visible
        hasChanges = true;
      }
    }

    if (hasChanges) {
      state = state.copyWith(showTankPressure: updated);
    }
  }

  /// Check if a specific tank's pressure is visible
  bool isTankPressureVisible(String tankId) {
    return state.showTankPressure[tankId] ?? true;
  }

  /// Reset all toggles to their default values
  void reset() {
    state = const ProfileLegendState();
  }
}
