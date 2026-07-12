import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';

/// Lightweight value type representing a dive's time bounds for matching.
///
/// Decoupled from the full Dive entity so the matcher can be unit-tested
/// without a database and reused from the Files tab (which doesn't pull
/// full dive entities).
class DiveBounds {
  final String diveId;
  final DateTime entryTime;
  final DateTime exitTime;

  const DiveBounds({
    required this.diveId,
    required this.entryTime,
    required this.exitTime,
  });
}

/// Routes [ExtractedFile]s to dives by matching their EXIF [takenAt]
/// against each dive's `[entryTime - preBuffer, exitTime + postBuffer]`
/// window.
///
/// Used by both the Files-tab (Phase 2) and the existing gallery scan
/// (TripMediaScanner, Task 4) so both paths produce identical assignments
/// for the same input.
///
/// Tie-breaker for overlapping windows: the dive whose [entryTime] is
/// closest to the file's [takenAt] in absolute Duration.
///
/// Files with no [takenAt] or no matching dive go to [MatchedSelection.unmatched].
class DivePhotoMatcher {
  const DivePhotoMatcher();

  /// Pre-dive buffer applied before [DiveBounds.entryTime] when computing
  /// the match window. Catches photos taken at the boat / dock / on the
  /// surface before the descent.
  static const Duration preBuffer = Duration(minutes: 30);

  /// Post-dive buffer applied after [DiveBounds.exitTime] when computing
  /// the match window. Catches surface-interval shots, debrief photos.
  static const Duration postBuffer = Duration(minutes: 60);

  /// Routes [files] to [dives] by EXIF date.
  MatchedSelection match({
    required List<ExtractedFile> files,
    required List<DiveBounds> dives,
  }) {
    final matched = <String, List<ExtractedFile>>{};
    final unmatched = <ExtractedFile>[];

    for (final file in files) {
      final takenAt = file.metadata.takenAt;
      if (takenAt == null) {
        unmatched.add(file);
        continue;
      }

      DiveBounds? best;
      Duration? bestDelta;
      for (final dive in dives) {
        final windowStart = dive.entryTime.subtract(preBuffer);
        final windowEnd = dive.exitTime.add(postBuffer);
        if (takenAt.isBefore(windowStart) || takenAt.isAfter(windowEnd)) {
          continue;
        }
        final delta = takenAt.difference(dive.entryTime).abs();
        if (best == null || delta < bestDelta!) {
          best = dive;
          bestDelta = delta;
        }
      }

      if (best == null) {
        unmatched.add(file);
      } else {
        matched.putIfAbsent(best.diveId, () => []).add(file);
      }
    }

    return MatchedSelection(matched: matched, unmatched: unmatched);
  }

  /// Confidence-bearing match of a single timestamp against dive windows
  /// (Lightroom auto-linking; adoptable by the gallery scanner later).
  ///
  /// Extended window = `[entry - preBuffer, exit + postBuffer]`, core
  /// window = `[entry, exit]`, boundaries inclusive.
  /// - No extended hit: [TimestampMatchKind.none].
  /// - Exactly one extended hit: confident.
  /// - Several extended hits with exactly one core hit: confident for the
  ///   core dive (a photo taken during dive B also lands in dive A's
  ///   post-margin; the core hit is unambiguous).
  /// - Otherwise ambiguous, candidates ordered by |takenAt - entry|.
  TimestampMatch matchTimestamp({
    required DateTime takenAt,
    required List<DiveBounds> dives,
  }) {
    bool inExtended(DiveBounds d) =>
        !takenAt.isBefore(d.entryTime.subtract(preBuffer)) &&
        !takenAt.isAfter(d.exitTime.add(postBuffer));
    bool inCore(DiveBounds d) =>
        !takenAt.isBefore(d.entryTime) && !takenAt.isAfter(d.exitTime);

    final extended = dives.where(inExtended).toList();
    if (extended.isEmpty) {
      return const TimestampMatch(kind: TimestampMatchKind.none);
    }
    if (extended.length == 1) {
      return TimestampMatch(
        kind: TimestampMatchKind.confident,
        diveId: extended.single.diveId,
      );
    }
    final core = extended.where(inCore).toList();
    if (core.length == 1) {
      return TimestampMatch(
        kind: TimestampMatchKind.confident,
        diveId: core.single.diveId,
      );
    }
    extended.sort(
      (a, b) => takenAt
          .difference(a.entryTime)
          .abs()
          .compareTo(takenAt.difference(b.entryTime).abs()),
    );
    return TimestampMatch(
      kind: TimestampMatchKind.ambiguous,
      candidateDiveIds: [for (final d in extended) d.diveId],
    );
  }
}

/// Outcome kinds for [DivePhotoMatcher.matchTimestamp].
enum TimestampMatchKind { confident, ambiguous, none }

/// Result of matching one timestamp against dive windows.
class TimestampMatch {
  const TimestampMatch({
    required this.kind,
    this.diveId,
    this.candidateDiveIds = const [],
  });

  final TimestampMatchKind kind;

  /// The matched dive when [kind] is confident.
  final String? diveId;

  /// Candidate dives when [kind] is ambiguous, closest entry first.
  final List<String> candidateDiveIds;
}
