import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_legend_provider.g.dart';

/// Immutable state for dive profile chart legend toggles.
///
/// Separates "primary" toggles (commonly used, always visible) from
/// "secondary" toggles (less common, shown in popover menu).
@immutable
class ProfileLegendState {
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

  // Per-tank pressure visibility (keyed by tank ID)
  final Map<String, bool> showTankPressure;

  const ProfileLegendState({
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
    this.showTankPressure = const {},
  });

  /// Count of active secondary toggles (for badge display)
  int get activeSecondaryCount {
    var count = 0;
    if (showHeartRate) count++;
    if (showSac) count++;
    if (showAscentRateColors) count++;
    if (showEvents) count++;
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
    count += showTankPressure.values.where((v) => v).length;
    return count;
  }

  /// Whether any secondary toggle is active
  bool get hasActiveSecondary => activeSecondaryCount > 0;

  ProfileLegendState copyWith({
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
    Map<String, bool>? showTankPressure,
  }) {
    return ProfileLegendState(
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
      showTankPressure: showTankPressure ?? this.showTankPressure,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileLegendState &&
          runtimeType == other.runtimeType &&
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
          mapEquals(showTankPressure, other.showTankPressure);

  @override
  int get hashCode => Object.hashAll([
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
    ...showTankPressure.entries,
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
  // Track if pressure default has been initialized for this session
  bool _pressureInitialized = false;

  @override
  ProfileLegendState build() => const ProfileLegendState();

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

  /// Enable pressure display by default when pressure data is available.
  /// Only runs once per session to avoid overriding user's explicit toggle.
  void enablePressureIfAvailable() {
    if (_pressureInitialized) return;
    _pressureInitialized = true;
    state = state.copyWith(showPressure: true);
  }
}
