import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

/// A remote dive matched to a local dive (same physical dive). Photo sync
/// (Phase 4) walks these pairs.
class DivelogsMatchedDive {
  final String remoteId;
  final String localDiveId;
  final DateTime localTime;

  const DivelogsMatchedDive({
    required this.remoteId,
    required this.localDiveId,
    required this.localTime,
  });
}

/// Result of comparing the remote divelist with local dive summaries.
class DivelogsSyncPlan {
  final List<DivelogsDivelistEntry> pullCandidates;
  final List<DiveSummary> pushCandidates;
  final List<DivelogsMatchedDive> matchedPairs;
  final int matchedCount;

  const DivelogsSyncPlan({
    required this.pullCandidates,
    required this.pushCandidates,
    required this.matchedPairs,
    required this.matchedCount,
  });
}

/// Stateless two-way diff for the create-only sync model (spec: sync
/// engine). Matching is time-gated (15 min, DiveMatcher's zero band) with
/// depth/duration refinement when both sides carry them; the undocumented
/// /divelist shape may omit depth/duration, in which case the time gate
/// alone decides (degraded but safe on a single user's account).
class DivelogsSyncPlanner {
  const DivelogsSyncPlanner({this.matcher = const DiveMatcher()});

  final DiveMatcher matcher;

  static const Duration _timeGate = Duration(minutes: 15);

  DivelogsSyncPlan plan({
    required List<DivelogsDivelistEntry> remote,
    required List<DiveSummary> local,
  }) {
    final sortedRemote = [...remote]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final unmatchedLocal = [...local];
    final pull = <DivelogsDivelistEntry>[];
    final matchedPairs = <DivelogsMatchedDive>[];

    for (final entry in sortedRemote) {
      DiveSummary? best;
      var bestKey = double.negativeInfinity;
      for (final summary in unmatchedLocal) {
        final key = _matchKey(entry, summary);
        if (key != null && key > bestKey) {
          best = summary;
          bestKey = key;
        }
      }
      if (best != null) {
        unmatchedLocal.remove(best);
        matchedPairs.add(
          DivelogsMatchedDive(
            remoteId: entry.id,
            localDiveId: best.id,
            localTime: best.entryTime ?? best.dateTime,
          ),
        );
      } else {
        pull.add(entry);
      }
    }

    return DivelogsSyncPlan(
      pullCandidates: pull,
      pushCandidates: unmatchedLocal,
      matchedPairs: matchedPairs,
      matchedCount: matchedPairs.length,
    );
  }

  /// Returns a comparable match quality (higher is better), or null when
  /// the pair does not match.
  double? _matchKey(DivelogsDivelistEntry entry, DiveSummary summary) {
    final localTime = summary.entryTime ?? summary.dateTime;
    final timeDiff = entry.dateTime.difference(localTime).abs();
    if (timeDiff > _timeGate) return null;

    final localDuration = summary.runtime ?? summary.bottomTime;
    final hasFullData =
        entry.durationSeconds != null &&
        entry.maxDepth != null &&
        localDuration != null &&
        summary.maxDepth != null;
    if (!hasFullData) {
      // Degraded: time-gate only. Rank by time proximity below any real
      // score so scored matches win when available.
      return -timeDiff.inSeconds.toDouble() / _timeGate.inSeconds;
    }

    final score = matcher.calculateMatchScore(
      wearableStartTime: entry.dateTime,
      wearableMaxDepth: entry.maxDepth!,
      wearableDurationSeconds: entry.durationSeconds!,
      existingStartTime: localTime,
      existingMaxDepth: summary.maxDepth!,
      existingDurationSeconds: localDuration.inSeconds,
    );
    // Probable (>= 0.7), not merely possible (>= 0.5): a perfect time match
    // alone scores exactly 0.5, and treating that as "already synced" would
    // silently hide a dive whose depth/duration clearly disagree.
    return matcher.isProbableDuplicate(score) ? score : null;
  }
}
