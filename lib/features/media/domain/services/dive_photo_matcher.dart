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
}
