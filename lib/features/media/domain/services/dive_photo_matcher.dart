import 'package:submersion/features/media/domain/entities/media_dive_window.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/unmatched_diagnostic.dart';

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
/// Files with no [takenAt] or no matching dive go to [MatchedSelection.unmatched],
/// each with an [UnmatchedDiagnostic] recording which of the two it was.
///
/// [match] also accepts an `offset` that shifts every file's capture time
/// before comparison, which is how the Files tab corrects a camera clock left
/// on the wrong timezone (issue #312).
class DivePhotoMatcher {
  const DivePhotoMatcher();

  /// Pre-dive buffer applied before [DiveBounds.entryTime] when computing
  /// the match window. Catches photos taken at the boat / dock / on the
  /// surface before the descent.
  static const Duration preBuffer = MediaDiveWindow.before;

  /// Post-dive buffer applied after [DiveBounds.exitTime] when computing
  /// the match window. Catches surface-interval shots, debrief photos.
  static const Duration postBuffer = MediaDiveWindow.after;

  /// Routes [files] to [dives] by capture date.
  ///
  /// [offset] is added to each file's `takenAt` before comparison and is not
  /// written back to the file. The caller owns applying the same offset when
  /// persisting, so a shift-rescued photo enriches against the same corrected
  /// time it matched on.
  ///
  /// Files that match nothing land in [MatchedSelection.unmatched] with an
  /// [UnmatchedDiagnostic] in [MatchedSelection.diagnostics] saying why.
  MatchedSelection match({
    required List<ExtractedFile> files,
    required List<DiveBounds> dives,
    Duration offset = Duration.zero,
  }) {
    final matched = <String, List<ExtractedFile>>{};
    final unmatched = <ExtractedFile>[];
    final diagnostics = <String, UnmatchedDiagnostic>{};

    for (final file in files) {
      final rawTakenAt = file.metadata.takenAt;
      if (rawTakenAt == null) {
        unmatched.add(file);
        diagnostics[file.sourcePath] = const UnmatchedDiagnostic(
          reason: UnmatchedReason.noTimestamp,
        );
        continue;
      }
      final takenAt = rawTakenAt.add(offset);

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
        diagnostics[file.sourcePath] = _outsideDiagnostic(takenAt, dives);
      } else {
        matched.putIfAbsent(best.diveId, () => []).add(file);
      }
    }

    return MatchedSelection(
      matched: matched,
      unmatched: unmatched,
      diagnostics: diagnostics,
    );
  }

  /// Finds the dive whose match window [takenAt] came closest to.
  ///
  /// The distance is measured to the window edge rather than to entry time, so
  /// the reported gap is the amount of shift that would actually bring the
  /// file into range. Measuring to entry time would overstate the required
  /// correction by the whole pre- or post-buffer.
  static UnmatchedDiagnostic _outsideDiagnostic(
    DateTime takenAt,
    List<DiveBounds> dives,
  ) {
    String? nearestDiveId;
    Duration? nearestGap;
    for (final dive in dives) {
      final windowStart = dive.entryTime.subtract(preBuffer);
      final windowEnd = dive.exitTime.add(postBuffer);
      final gap = takenAt.isBefore(windowStart)
          ? takenAt.difference(windowStart)
          : takenAt.difference(windowEnd);
      if (nearestGap == null || gap.abs() < nearestGap.abs()) {
        nearestGap = gap;
        nearestDiveId = dive.diveId;
      }
    }
    return UnmatchedDiagnostic(
      reason: UnmatchedReason.outsideAllWindows,
      nearestDiveId: nearestDiveId,
      gapToNearest: nearestGap,
    );
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
