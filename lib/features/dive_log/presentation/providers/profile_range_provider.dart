import 'package:equatable/equatable.dart';

import '../../../../core/providers/provider.dart';

/// State for profile range selection functionality.
///
/// Manages a selectable time range on the dive profile for analyzing
/// statistics within a specific portion of the dive.
class RangeSelectionState extends Equatable {
  /// Whether range selection mode is active
  final bool isEnabled;

  /// Start of the selected range in seconds from dive start
  final int? startTimestamp;

  /// End of the selected range in seconds from dive start
  final int? endTimestamp;

  /// Maximum timestamp in seconds (dive duration)
  final int maxTimestamp;

  const RangeSelectionState({
    this.isEnabled = false,
    this.startTimestamp,
    this.endTimestamp,
    this.maxTimestamp = 0,
  });

  /// Whether a valid range is selected
  bool get hasSelection =>
      startTimestamp != null &&
      endTimestamp != null &&
      startTimestamp! < endTimestamp!;

  /// Duration of the selected range in seconds
  int get selectionDuration {
    if (!hasSelection) return 0;
    return endTimestamp! - startTimestamp!;
  }

  /// Start progress as a value from 0.0 to 1.0
  double get startProgress {
    if (startTimestamp == null || maxTimestamp == 0) return 0.0;
    return startTimestamp! / maxTimestamp;
  }

  /// End progress as a value from 0.0 to 1.0
  double get endProgress {
    if (endTimestamp == null || maxTimestamp == 0) return 1.0;
    return endTimestamp! / maxTimestamp;
  }

  /// Selection duration formatted as MM:SS
  String get formattedDuration {
    final seconds = selectionDuration;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Format a timestamp as MM:SS
  static String formatTimestamp(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  RangeSelectionState copyWith({
    bool? isEnabled,
    int? startTimestamp,
    int? endTimestamp,
    int? maxTimestamp,
    bool clearSelection = false,
  }) {
    return RangeSelectionState(
      isEnabled: isEnabled ?? this.isEnabled,
      startTimestamp: clearSelection
          ? null
          : (startTimestamp ?? this.startTimestamp),
      endTimestamp: clearSelection ? null : (endTimestamp ?? this.endTimestamp),
      maxTimestamp: maxTimestamp ?? this.maxTimestamp,
    );
  }

  @override
  List<Object?> get props => [
    isEnabled,
    startTimestamp,
    endTimestamp,
    maxTimestamp,
  ];
}

/// Notifier for managing profile range selection state.
class RangeSelectionNotifier extends StateNotifier<RangeSelectionState> {
  RangeSelectionNotifier() : super(const RangeSelectionState());

  /// Initialize with the dive duration
  void initialize(int durationSeconds) {
    state = RangeSelectionState(
      maxTimestamp: durationSeconds,
      isEnabled: false,
    );
  }

  /// Toggle range selection mode on/off
  void toggleRangeMode() {
    if (state.isEnabled) {
      // Turning off - clear selection
      state = state.copyWith(isEnabled: false, clearSelection: true);
    } else {
      // Turning on - set default selection to middle 50%
      final start = state.maxTimestamp ~/ 4;
      final end = (state.maxTimestamp * 3) ~/ 4;
      state = state.copyWith(
        isEnabled: true,
        startTimestamp: start,
        endTimestamp: end,
      );
    }
  }

  /// Enable range mode (if not already enabled)
  void enableRangeMode() {
    if (!state.isEnabled) {
      toggleRangeMode();
    }
  }

  /// Disable range mode
  void disableRangeMode() {
    if (state.isEnabled) {
      state = state.copyWith(isEnabled: false, clearSelection: true);
    }
  }

  /// Set the start timestamp
  void setStart(int timestamp) {
    if (!state.isEnabled) return;

    final clampedStart = timestamp.clamp(0, state.maxTimestamp);
    // Ensure start is before end
    final effectiveStart = state.endTimestamp != null
        ? clampedStart.clamp(0, state.endTimestamp! - 1)
        : clampedStart;

    state = state.copyWith(startTimestamp: effectiveStart);
  }

  /// Set the end timestamp
  void setEnd(int timestamp) {
    if (!state.isEnabled) return;

    final clampedEnd = timestamp.clamp(0, state.maxTimestamp);
    // Ensure end is after start
    final effectiveEnd = state.startTimestamp != null
        ? clampedEnd.clamp(state.startTimestamp! + 1, state.maxTimestamp)
        : clampedEnd;

    state = state.copyWith(endTimestamp: effectiveEnd);
  }

  /// Set both start and end timestamps
  void setRange(int start, int end) {
    if (!state.isEnabled) return;

    final clampedStart = start.clamp(0, state.maxTimestamp - 1);
    final clampedEnd = end.clamp(clampedStart + 1, state.maxTimestamp);

    state = state.copyWith(
      startTimestamp: clampedStart,
      endTimestamp: clampedEnd,
    );
  }

  /// Set start from a progress value (0.0 to 1.0)
  void setStartProgress(double progress) {
    final timestamp = (progress * state.maxTimestamp).round();
    setStart(timestamp);
  }

  /// Set end from a progress value (0.0 to 1.0)
  void setEndProgress(double progress) {
    final timestamp = (progress * state.maxTimestamp).round();
    setEnd(timestamp);
  }

  /// Clear the current selection but stay in range mode
  void clearSelection() {
    if (!state.isEnabled) return;

    // Reset to default selection
    final start = state.maxTimestamp ~/ 4;
    final end = (state.maxTimestamp * 3) ~/ 4;
    state = state.copyWith(startTimestamp: start, endTimestamp: end);
  }
}

/// Provider for range selection state, scoped by dive ID
final rangeSelectionProvider =
    StateNotifierProvider.family<
      RangeSelectionNotifier,
      RangeSelectionState,
      String
    >((ref, diveId) => RangeSelectionNotifier());
