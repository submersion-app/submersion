import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// One stretch of a video, from [startMs] up to (not including) [endMs].
typedef ScannedStretch = ({int startMs, int endMs});

/// The stretches of a video already scanned (issue #4709): sorted, never
/// overlapping, merged where they touch, and never empty. Immutable.
class ScannedRanges extends Equatable {
  /// Nothing scanned yet.
  const ScannedRanges() : stretches = const [];

  const ScannedRanges._(this.stretches);

  /// [stretches] in any order, sorted and merged, empty ones left out.
  factory ScannedRanges.of(Iterable<ScannedStretch> stretches) => stretches
      .fold(const ScannedRanges(), (all, s) => all.add(s.startMs, s.endMs));

  /// Scanned from the start up to [endMs]: how a run stored before the
  /// stretches were kept reads its single mark. Empty for [endMs] <= 0.
  factory ScannedRanges.prefix(int endMs) => endMs <= 0
      ? const ScannedRanges()
      : ScannedRanges._(List.unmodifiable([(startMs: 0, endMs: endMs)]));

  final List<ScannedStretch> stretches;

  /// With [stretches] in place of these, sorted and merged.
  ScannedRanges copyWith({List<ScannedStretch>? stretches}) =>
      stretches == null ? this : ScannedRanges.of(stretches);

  /// These stretches with [startMs] to [endMs] added. Nothing changes for
  /// an empty stretch.
  ScannedRanges add(int startMs, int endMs) {
    if (endMs <= startMs) return this;
    final sorted = [...stretches, (startMs: startMs, endMs: endMs)]
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    final merged = <ScannedStretch>[];
    for (final s in sorted) {
      if (merged.isNotEmpty && s.startMs <= merged.last.endMs) {
        final last = merged.removeLast();
        merged.add((
          startMs: last.startMs,
          endMs: math.max(last.endMs, s.endMs),
        ));
      } else {
        merged.add(s);
      }
    }
    return ScannedRanges._(List.unmodifiable(merged));
  }

  /// Whether the moment [ms] is scanned.
  bool covers(int ms) => stretches.any((s) => s.startMs <= ms && ms < s.endMs);

  /// Whether all of [startMs] to [endMs] lies in one scanned stretch.
  bool coversRange(int startMs, int endMs) =>
      stretches.any((s) => s.startMs <= startMs && endMs <= s.endMs);

  /// How much of a video [durationMs] long is scanned.
  int coveredMs(int durationMs) {
    var total = 0;
    for (final s in stretches) {
      final end = math.min(s.endMs, durationMs);
      if (end > s.startMs) total += end - s.startMs;
    }
    return total;
  }

  /// The first moment at or after [ms] not yet scanned. Null when none is
  /// left before [durationMs]; with [durationMs] null the video is taken to
  /// run on for ever.
  int? firstGapAtOrAfter(int ms, {int? durationMs}) {
    var at = math.max(0, ms);
    for (final s in stretches) {
      if (s.endMs <= at) continue;
      if (s.startMs > at) break;
      at = s.endMs;
    }
    if (durationMs != null && at >= durationMs) return null;
    return at;
  }

  /// Where the first stretch beginning after [ms] starts, or null.
  int? stretchStartAfter(int ms) {
    for (final s in stretches) {
      if (s.startMs > ms) return s.startMs;
    }
    return null;
  }

  /// The end of the stretch that starts at 0, or 0 when none does: the
  /// older "scanned from the start up to here" mark.
  int get prefixEndMs => stretches.isNotEmpty && stretches.first.startMs == 0
      ? stretches.first.endMs
      : 0;

  /// Whether the stretches cover all of a video [durationMs] long.
  bool isComplete(int durationMs) =>
      firstGapAtOrAfter(0, durationMs: durationMs) == null;

  @override
  List<Object?> get props => [stretches];
}
