import 'package:uuid/uuid.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
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
    required this.previewProfile,
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

  /// Depth-vs-time series for the confirmation preview: each source's
  /// profile re-based onto the merged timeline, bridged by 0-depth points
  /// across each gap. Preview-only -- the persisted profile is assembled
  /// row-by-row in [DiveMergeService] to preserve per-sample computer
  /// attribution and native-cadence surface samples. Empty when no source
  /// carries submerged profile data.
  final List<DiveProfilePoint> previewProfile;
}

class DiveMergeBuilder {
  const DiveMergeBuilder();

  static const _uuid = Uuid();

  T? _firstNonNull<T>(List<Dive> sorted, T? Function(Dive) pick) {
    for (final d in sorted) {
      final v = pick(d);
      if (v != null) return v;
    }
    return null;
  }

  T? _lastNonNull<T>(List<Dive> sorted, T? Function(Dive) pick) {
    for (final d in sorted.reversed) {
      final v = pick(d);
      if (v != null) return v;
    }
    return null;
  }

  String _mergedNotes(List<Dive> sorted) =>
      sorted.map((d) => d.notes.trim()).where((n) => n.isNotEmpty).join('\n\n');

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

    final mergedId = idGen();

    // Tanks: all kept, chronological, fresh ids, order re-sequenced.
    final tankIdMap = <String, String>{};
    final mergedTanks = <DiveTank>[];
    var tankOrder = 0;
    for (final d in sorted) {
      final tanksInOrder = [...d.tanks]
        ..sort((x, y) => x.order.compareTo(y.order));
      for (final tank in tanksInOrder) {
        final freshId = idGen();
        tankIdMap[tank.id] = freshId;
        mergedTanks.add(tank.copyWith(id: freshId, order: tankOrder++));
      }
    }

    // Weights: first source that has any (avoids double-counting lead).
    final weightSource = sorted.firstWhere(
      (d) => d.weights.isNotEmpty,
      orElse: () => sorted.first,
    );
    final mergedWeights = [
      for (final w in weightSource.weights)
        DiveWeight(
          id: idGen(),
          diveId: mergedId,
          weightType: w.weightType,
          amountKg: w.amountKg,
          notes: w.notes,
        ),
    ];

    // Custom fields: union by key, first-in-order wins.
    final seenKeys = <String>{};
    final mergedCustomFields = <DiveCustomField>[];
    for (final d in sorted) {
      for (final f in d.customFields) {
        if (seenKeys.add(f.key)) {
          mergedCustomFields.add(
            DiveCustomField(
              id: idGen(),
              key: f.key,
              value: f.value,
              sortOrder: mergedCustomFields.length,
            ),
          );
        }
      }
    }

    // Tags: union by id, chronological order.
    final seenTagIds = <String>{};
    final mergedTags = <Tag>[
      for (final d in sorted)
        for (final t in tagsByDive[d.id] ?? const <Tag>[])
          if (seenTagIds.add(t.id)) t,
    ];

    // Dive types: ordered union (first dive's representative type stays first).
    final mergedDiveTypeIds = <String>[];
    for (final d in sorted) {
      for (final t in d.diveTypeIds) {
        if (!mergedDiveTypeIds.contains(t)) mergedDiveTypeIds.add(t);
      }
    }

    // Equipment: union by item id.
    final seenEquipment = <String>{};
    final mergedEquipment = [
      for (final d in sorted)
        for (final e in d.equipment)
          if (seenEquipment.add(e.id)) e,
    ];

    // Sightings: union; same species merged (counts summed, notes joined).
    final bySpecies = <String, MarineSighting>{};
    for (final d in sorted) {
      for (final s in sightingsByDive[d.id] ?? const <MarineSighting>[]) {
        final existing = bySpecies[s.speciesId];
        if (existing == null) {
          bySpecies[s.speciesId] = MarineSighting(
            id: idGen(),
            speciesId: s.speciesId,
            speciesName: s.speciesName,
            count: s.count,
            notes: s.notes,
          );
        } else {
          final notes = [
            existing.notes,
            s.notes,
          ].where((n) => n.trim().isNotEmpty).join('; ');
          bySpecies[s.speciesId] = MarineSighting(
            id: existing.id,
            speciesId: existing.speciesId,
            speciesName: existing.speciesName,
            count: existing.count + s.count,
            notes: notes,
          );
        }
      }
    }

    final mergedDive = Dive(
      id: mergedId,
      diverId: first.diverId,
      dateTime: first.dateTime,
      entryTime: mergedStart,
      exitTime: mergedEnd,
      runtime: mergedEnd.difference(mergedStart),
      bottomTime: _mergedBottomTime(sorted),
      maxDepth: _mergedMaxDepth(sorted),
      avgDepth: _mergedAvgDepth(sorted),
      diveNumber: first.diveNumber,
      surfaceInterval: first.surfaceInterval,
      diveMode: first.diveMode,
      isPlanned: first.isPlanned,
      notes: _mergedNotes(sorted),
      isFavorite: sorted.any((d) => d.isFavorite),
      entryLocation: _firstNonNull(sorted, (d) => d.entryLocation),
      exitLocation: _lastNonNull(sorted, (d) => d.exitLocation),
      site: _firstNonNull(sorted, (d) => d.site),
      diveCenter: _firstNonNull(sorted, (d) => d.diveCenter),
      trip: _firstNonNull(sorted, (d) => d.trip),
      tripId: _firstNonNull(sorted, (d) => d.tripId),
      tanks: mergedTanks,
      buddy: _firstNonNull(sorted, (d) => d.buddy),
      diveMaster: _firstNonNull(sorted, (d) => d.diveMaster),
      rating: _firstNonNull(sorted, (d) => d.rating),
      visibility: _firstNonNull(sorted, (d) => d.visibility),
      waterTemp: _firstNonNull(sorted, (d) => d.waterTemp),
      airTemp: _firstNonNull(sorted, (d) => d.airTemp),
      currentDirection: _firstNonNull(sorted, (d) => d.currentDirection),
      currentStrength: _firstNonNull(sorted, (d) => d.currentStrength),
      swellHeight: _firstNonNull(sorted, (d) => d.swellHeight),
      entryMethod: _firstNonNull(sorted, (d) => d.entryMethod),
      exitMethod: _firstNonNull(sorted, (d) => d.exitMethod),
      waterType: _firstNonNull(sorted, (d) => d.waterType),
      altitude: _firstNonNull(sorted, (d) => d.altitude),
      surfacePressure: _firstNonNull(sorted, (d) => d.surfacePressure),
      gradientFactorLow: _firstNonNull(sorted, (d) => d.gradientFactorLow),
      gradientFactorHigh: _firstNonNull(sorted, (d) => d.gradientFactorHigh),
      decoAlgorithm: _firstNonNull(sorted, (d) => d.decoAlgorithm),
      decoConservatism: _firstNonNull(sorted, (d) => d.decoConservatism),
      diveComputerModel: _firstNonNull(sorted, (d) => d.diveComputerModel),
      diveComputerSerial: _firstNonNull(sorted, (d) => d.diveComputerSerial),
      diveComputerFirmware: _firstNonNull(
        sorted,
        (d) => d.diveComputerFirmware,
      ),
      weightAmount: _firstNonNull(sorted, (d) => d.weightAmount),
      weightType: _firstNonNull(sorted, (d) => d.weightType),
      weights: mergedWeights,
      tags: mergedTags,
      setpointLow: _firstNonNull(sorted, (d) => d.setpointLow),
      setpointHigh: _firstNonNull(sorted, (d) => d.setpointHigh),
      setpointDeco: _firstNonNull(sorted, (d) => d.setpointDeco),
      scrType: _firstNonNull(sorted, (d) => d.scrType),
      scrInjectionRate: _firstNonNull(sorted, (d) => d.scrInjectionRate),
      scrAdditionRatio: _firstNonNull(sorted, (d) => d.scrAdditionRatio),
      scrOrificeSize: _firstNonNull(sorted, (d) => d.scrOrificeSize),
      assumedVo2: _firstNonNull(sorted, (d) => d.assumedVo2),
      diluentGas: _firstNonNull(sorted, (d) => d.diluentGas),
      loopO2Min: _firstNonNull(sorted, (d) => d.loopO2Min),
      loopO2Max: _firstNonNull(sorted, (d) => d.loopO2Max),
      loopO2Avg: _firstNonNull(sorted, (d) => d.loopO2Avg),
      loopVolume: _firstNonNull(sorted, (d) => d.loopVolume),
      scrubber: _firstNonNull(sorted, (d) => d.scrubber),
      courseId: _firstNonNull(sorted, (d) => d.courseId),
      importSource: _firstNonNull(sorted, (d) => d.importSource),
      importId: _firstNonNull(sorted, (d) => d.importId),
      diveTypeIds: mergedDiveTypeIds,
      equipment: mergedEquipment,
      customFields: mergedCustomFields,
      windSpeed: _firstNonNull(sorted, (d) => d.windSpeed),
      windDirection: _firstNonNull(sorted, (d) => d.windDirection),
      cloudCover: _firstNonNull(sorted, (d) => d.cloudCover),
      precipitation: _firstNonNull(sorted, (d) => d.precipitation),
      humidity: _firstNonNull(sorted, (d) => d.humidity),
      weatherDescription: _firstNonNull(sorted, (d) => d.weatherDescription),
      weatherSource: _firstNonNull(sorted, (d) => d.weatherSource),
      weatherFetchedAt: _firstNonNull(sorted, (d) => d.weatherFetchedAt),
    );

    return DiveMergeResult(
      mergedDive: mergedDive,
      sortedSources: sorted,
      gaps: classification.gaps,
      segmentOffsetsSeconds: offsets,
      tankIdMap: tankIdMap,
      mergedSightings: bySpecies.values.toList(),
      previewProfile: _previewProfile(sorted, offsets, classification.gaps),
    );
  }

  /// Builds the preview depth series: each source's profile shifted by its
  /// [offsets] onto the merged timeline, with each gap filled by 0-depth
  /// points at the surrounding native cadence so the surface interval reads
  /// as a genuinely flat line -- and, being proportionally dense, survives
  /// the preview chart's downsampling instead of collapsing to a diagonal
  /// (#449 manual test). Mirrors the gap fill [DiveMergeService] persists.
  /// Returns an empty list when nothing submerged is present to preview.
  List<DiveProfilePoint> _previewProfile(
    List<Dive> sorted,
    Map<String, int> offsets,
    List<MergeGap> gaps,
  ) {
    final points = <DiveProfilePoint>[];
    for (var i = 0; i < sorted.length; i++) {
      final offset = offsets[sorted[i].id] ?? 0;
      final ordered = [...sorted[i].profile]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      for (final p in ordered) {
        points.add(
          DiveProfilePoint(timestamp: p.timestamp + offset, depth: p.depth),
        );
      }
      if (i < gaps.length && gaps[i].endSeconds > gaps[i].startSeconds) {
        final gap = gaps[i];
        final cadence = _previewGapCadence(sorted[i], sorted[i + 1]);
        // Cap the fill so a very long surface interval cannot explode the
        // series; a few hundred flat points render identically anyway.
        final minStep = ((gap.endSeconds - gap.startSeconds) / 300).ceil();
        final step = cadence > minStep ? cadence : minStep;
        for (var t = gap.startSeconds; t < gap.endSeconds; t += step) {
          points.add(DiveProfilePoint(timestamp: t, depth: 0));
        }
        points.add(DiveProfilePoint(timestamp: gap.endSeconds, depth: 0));
      }
    }
    // A series that never leaves the surface (no submerged samples) is not
    // worth previewing.
    if (points.every((p) => p.depth == 0)) return const [];
    return points;
  }

  /// The native sample cadence to fill a gap with: the median inter-sample
  /// delta of the previous segment, falling back to the next segment's, then
  /// to 60s when neither has samples. Parallels
  /// `DiveMergeService._nativeSampleIntervalSeconds` on the domain profile.
  int _previewGapCadence(Dive prev, Dive next) {
    for (final d in [prev, next]) {
      final timestamps = d.profile.map((p) => p.timestamp).toList()..sort();
      final deltas = <int>[
        for (var i = 1; i < timestamps.length; i++)
          if (timestamps[i] - timestamps[i - 1] > 0)
            timestamps[i] - timestamps[i - 1],
      ];
      if (deltas.isNotEmpty) {
        deltas.sort();
        return deltas[deltas.length ~/ 2];
      }
    }
    return 60;
  }

  /// The segment's occupied span: the declared runtime or the last profile
  /// sample, whichever is later. Computers routinely keep sampling past the
  /// runtime they report (surface bobbing before the log closes), so gap
  /// boundaries must clear the real samples or the seam is left with an
  /// uncovered sample hole (#449 manual-test bug).
  Duration _segmentExtent(Dive dive) {
    var extent = dive.effectiveRuntime ?? Duration.zero;
    for (final point in dive.profile) {
      if (point.timestamp > extent.inSeconds) {
        extent = Duration(seconds: point.timestamp);
      }
    }
    return extent;
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
      final prevEnd = prev.effectiveEntryTime.add(_segmentExtent(prev));
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
