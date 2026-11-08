import 'package:equatable/equatable.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/minutes_seconds.dart';

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

  /// Earliest timestamp in seconds: 0, or the first sample of a series that
  /// starts before the primary does (#4296).
  final int minTimestamp;

  const RangeSelectionState({
    this.isEnabled = false,
    this.startTimestamp,
    this.endTimestamp,
    this.maxTimestamp = 0,
    this.minTimestamp = 0,
  });

  int get _span => maxTimestamp - minTimestamp;

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
    if (startTimestamp == null || _span <= 0) return 0.0;
    return (startTimestamp! - minTimestamp) / _span;
  }

  /// End progress as a value from 0.0 to 1.0
  double get endProgress {
    if (endTimestamp == null || _span <= 0) return 1.0;
    return (endTimestamp! - minTimestamp) / _span;
  }

  /// Selection duration formatted as MM:SS
  String get formattedDuration => formatPaddedMinutesSeconds(selectionDuration);

  /// Format a timestamp as MM:SS, signed before 0
  static String formatTimestamp(int seconds) =>
      formatPaddedMinutesSeconds(seconds);

  RangeSelectionState copyWith({
    bool? isEnabled,
    int? startTimestamp,
    int? endTimestamp,
    int? maxTimestamp,
    int? minTimestamp,
    bool clearSelection = false,
  }) {
    return RangeSelectionState(
      isEnabled: isEnabled ?? this.isEnabled,
      startTimestamp: clearSelection
          ? null
          : (startTimestamp ?? this.startTimestamp),
      endTimestamp: clearSelection ? null : (endTimestamp ?? this.endTimestamp),
      maxTimestamp: maxTimestamp ?? this.maxTimestamp,
      minTimestamp: minTimestamp ?? this.minTimestamp,
    );
  }

  @override
  List<Object?> get props => [
    isEnabled,
    startTimestamp,
    endTimestamp,
    maxTimestamp,
    minTimestamp,
  ];
}

/// Notifier for managing profile range selection state.
class RangeSelectionNotifier extends StateNotifier<RangeSelectionState> {
  RangeSelectionNotifier() : super(const RangeSelectionState());

  /// Initialize with the dive duration, and with [startSeconds] for a
  /// series whose first sample comes before the primary's start (#4296).
  void initialize(int durationSeconds, {int startSeconds = 0}) {
    state = RangeSelectionState(
      maxTimestamp: durationSeconds,
      minTimestamp: startSeconds,
      isEnabled: false,
    );
  }

  /// The middle half of the series, the selection range mode starts with.
  (int, int) _defaultRange() {
    final span = state.maxTimestamp - state.minTimestamp;
    return (
      state.minTimestamp + span ~/ 4,
      state.minTimestamp + (span * 3) ~/ 4,
    );
  }

  /// Toggle range selection mode on/off
  void toggleRangeMode() {
    if (state.isEnabled) {
      // Turning off - clear selection
      state = state.copyWith(isEnabled: false, clearSelection: true);
    } else {
      // Turning on - set default selection to middle 50%
      final (start, end) = _defaultRange();
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

    final min = state.minTimestamp;
    final clampedStart = timestamp.clamp(min, state.maxTimestamp);
    // Ensure start is before end
    final effectiveStart = state.endTimestamp != null
        ? clampedStart.clamp(min, state.endTimestamp! - 1)
        : clampedStart;

    state = state.copyWith(startTimestamp: effectiveStart);
  }

  /// Set the end timestamp
  void setEnd(int timestamp) {
    if (!state.isEnabled) return;

    final clampedEnd = timestamp.clamp(state.minTimestamp, state.maxTimestamp);
    // Ensure end is after start
    final effectiveEnd = state.startTimestamp != null
        ? clampedEnd.clamp(state.startTimestamp! + 1, state.maxTimestamp)
        : clampedEnd;

    state = state.copyWith(endTimestamp: effectiveEnd);
  }

  /// Set both start and end timestamps
  void setRange(int start, int end) {
    if (!state.isEnabled) return;

    final clampedStart = start.clamp(
      state.minTimestamp,
      state.maxTimestamp - 1,
    );
    final clampedEnd = end.clamp(clampedStart + 1, state.maxTimestamp);

    state = state.copyWith(
      startTimestamp: clampedStart,
      endTimestamp: clampedEnd,
    );
  }

  /// Set start from a progress value (0.0 to 1.0)
  void setStartProgress(double progress) => setStart(_atProgress(progress));

  /// The timestamp [progress] (0.0 to 1.0) of the way through the series.
  int _atProgress(double progress) =>
      state.minTimestamp +
      (progress * (state.maxTimestamp - state.minTimestamp)).round();

  /// Set end from a progress value (0.0 to 1.0)
  void setEndProgress(double progress) => setEnd(_atProgress(progress));

  /// Clear the current selection but stay in range mode
  void clearSelection() {
    if (!state.isEnabled) return;

    // Reset to default selection
    final (start, end) = _defaultRange();
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
