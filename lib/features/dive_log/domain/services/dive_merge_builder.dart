import 'package:uuid/uuid.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// Why a merge was rejected outright (neither sequential nor overlapping).
enum DiveMergeInvalidReason { tooFewDives, mixedDivers }

/// One inter-dive surface gap on the merged timeline.
class MergeGap {
  const MergeGap({
    required this.afterDiveId,
    required this.beforeDiveId,
    required this.startSeconds,
    required this.endSeconds,
  });

  /// The gap follows this source dive.
  final String afterDiveId;

  /// The gap precedes this source dive.
  final String beforeDiveId;

  /// Seconds from the merged dive's start.
  final int startSeconds;
  final int endSeconds;

  Duration get duration => Duration(seconds: endSeconds - startSeconds);
}

sealed class DiveMergeClassification {
  const DiveMergeClassification();
}

class MergeInvalid extends DiveMergeClassification {
  const MergeInvalid(this.reason);
  final DiveMergeInvalidReason reason;
}

/// Any pair of dives overlaps in time — these look like the same dive from
/// multiple computers (future feature), not a sequential combine.
class MergeOverlapping extends DiveMergeClassification {
  const MergeOverlapping();
}

class MergeSequential extends DiveMergeClassification {
  const MergeSequential({required this.sortedDives, required this.gaps});
  final List<Dive> sortedDives;
  final List<MergeGap> gaps;
}

/// Everything the merge service needs to persist a sequential combine.
class DiveMergeResult {
  const DiveMergeResult({
    required this.mergedDive,
    required this.sortedSources,
    required this.gaps,
    required this.segmentOffsetsSeconds,
    required this.tankIdMap,
    required this.mergedSightings,
  });

  final Dive mergedDive;
  final List<Dive> sortedSources;
  final List<MergeGap> gaps;

  /// Source dive id -> seconds to add to that segment's profile timestamps.
  final Map<String, int> segmentOffsetsSeconds;

  /// Old source tank id -> fresh tank id on the merged dive.
  final Map<String, String> tankIdMap;

  /// Union of source sightings (same species merged), with fresh ids.
  final List<MarineSighting> mergedSightings;
}

class DiveMergeBuilder {
  const DiveMergeBuilder();

  static const _uuid = Uuid();

  /// Trapezoidal time-weighted mean depth over one segment's samples.
  /// Returns (weightedAreaMeterSeconds, spanSeconds) or null if < 2 samples.
  (double, int)? _profileDepthArea(List<DiveProfilePoint> profile) {
    if (profile.length < 2) return null;
    final sorted = [...profile]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    var area = 0.0;
    var span = 0;
    for (var i = 0; i < sorted.length - 1; i++) {
      final dt = sorted[i + 1].timestamp - sorted[i].timestamp;
      if (dt <= 0) continue;
      area += dt * (sorted[i].depth + sorted[i + 1].depth) / 2;
      span += dt;
    }
    return span > 0 ? (area, span) : null;
  }

  Duration? _mergedBottomTime(List<Dive> sorted) {
    var total = Duration.zero;
    var any = false;
    for (final d in sorted) {
      final bt =
          d.bottomTime ??
          d.calculateBottomTimeFromProfile() ??
          d.effectiveRuntime;
      if (bt != null && bt > Duration.zero) {
        total += bt;
        any = true;
      }
    }
    return any ? total : null;
  }

  double? _mergedMaxDepth(List<Dive> sorted) {
    double? max;
    for (final d in sorted) {
      final m = d.maxDepth ?? d.calculateMaxDepthFromProfile();
      if (m != null && (max == null || m > max)) max = m;
    }
    return max;
  }

  double? _mergedAvgDepth(List<Dive> sorted) {
    var area = 0.0;
    var span = 0;
    for (final d in sorted) {
      final fromProfile = _profileDepthArea(d.profile);
      if (fromProfile != null) {
        area += fromProfile.$1;
        span += fromProfile.$2;
      } else if (d.avgDepth != null) {
        final w = (d.effectiveRuntime ?? Duration.zero).inSeconds;
        if (w > 0) {
          area += d.avgDepth! * w;
          span += w;
        }
      }
    }
    return span > 0 ? area / span : null;
  }

  DiveMergeResult build(
    List<Dive> dives, {
    Map<String, List<Tag>> tagsByDive = const {},
    Map<String, List<MarineSighting>> sightingsByDive = const {},
    String Function()? idGenerator,
  }) {
    final classification = classify(dives);
    if (classification is! MergeSequential) {
      throw ArgumentError(
        'build() requires a sequential selection; got $classification',
      );
    }
    final idGen = idGenerator ?? _uuid.v4;
    final sorted = classification.sortedDives;
    final first = sorted.first;
    final last = sorted.last;

    final mergedStart = first.effectiveEntryTime;
    final mergedEnd =
        last.exitTime ??
        last.effectiveEntryTime.add(last.effectiveRuntime ?? Duration.zero);

    final offsets = <String, int>{
      for (final d in sorted)
        d.id: d.effectiveEntryTime.difference(mergedStart).inSeconds,
    };

    final mergedDive = Dive(
      id: idGen(),
      diverId: first.diverId,
      dateTime: first.dateTime,
      entryTime: mergedStart,
      exitTime: mergedEnd,
      runtime: mergedEnd.difference(mergedStart),
      bottomTime: _mergedBottomTime(sorted),
      maxDepth: _mergedMaxDepth(sorted),
      avgDepth: _mergedAvgDepth(sorted),
    );

    return DiveMergeResult(
      mergedDive: mergedDive,
      sortedSources: sorted,
      gaps: classification.gaps,
      segmentOffsetsSeconds: offsets,
      tankIdMap: const {},
      mergedSightings: const [],
    );
  }

  DiveMergeClassification classify(List<Dive> dives) {
    if (dives.length < 2) {
      return const MergeInvalid(DiveMergeInvalidReason.tooFewDives);
    }
    if (dives.map((d) => d.diverId).toSet().length > 1) {
      return const MergeInvalid(DiveMergeInvalidReason.mixedDivers);
    }
    final sorted = [...dives]
      ..sort((a, b) => a.effectiveEntryTime.compareTo(b.effectiveEntryTime));
    final mergedStart = sorted.first.effectiveEntryTime;
    final gaps = <MergeGap>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final prev = sorted[i];
      final next = sorted[i + 1];
      // A dive with no derivable duration is treated as zero-length: it has
      // no profile samples, so nothing can overlap it. Deliberate (#449
      // review).
      final prevEnd = prev.effectiveEntryTime.add(
        prev.effectiveRuntime ?? Duration.zero,
      );
      if (next.effectiveEntryTime.isBefore(prevEnd)) {
        return const MergeOverlapping();
      }
      gaps.add(
        MergeGap(
          afterDiveId: prev.id,
          beforeDiveId: next.id,
          startSeconds: prevEnd.difference(mergedStart).inSeconds,
          endSeconds: next.effectiveEntryTime.difference(mergedStart).inSeconds,
        ),
      );
    }
    return MergeSequential(sortedDives: sorted, gaps: gaps);
  }
}
