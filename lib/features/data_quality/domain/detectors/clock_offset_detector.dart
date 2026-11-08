import 'package:collection/collection.dart';

import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';

class ClockOffsetDetector extends QualityDetector {
  const ClockOffsetDetector();

  @override
  String get id => 'clock_offset';
  @override
  int get version => 2;
  @override
  QualityCategory get category => QualityCategory.time;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final out = <QualityFinding>[];
    final entry = ctx.dive.effectiveEntryTime;

    if (entry.isAfter(
      ctx.now.add(const Duration(days: QualityThresholds.futureGraceDays)),
    )) {
      out.add(
        make(
          ctx,
          discriminator: 'future',
          severity: QualitySeverity.critical,
          params: {'entryTimeMs': entry.millisecondsSinceEpoch},
        ),
      );
    } else if (entry.year < QualityThresholds.minPlausibleYear) {
      out.add(
        make(
          ctx,
          discriminator: 'ancient',
          severity: QualitySeverity.warning,
          params: {'entryTimeMs': entry.millisecondsSinceEpoch},
        ),
      );
    }

    // Whole-hour offsets between sources: the unset-timezone signature.
    final primary =
        ctx.sources.firstWhereOrNull((s) => s.isPrimary) ??
        ctx.sources.firstOrNull;
    final primaryEntry = primary?.entryTime;
    if (primary != null && primaryEntry != null) {
      for (final s in ctx.sources) {
        final sEntry = s.entryTime;
        if (s.id == primary.id || sEntry == null) continue;
        final diffMin = sEntry.difference(primaryEntry).inMinutes;
        final hours = (diffMin / 60).round();
        final remainder = (diffMin - hours * 60).abs();
        if (hours.abs() >= QualityThresholds.hourOffsetMin &&
            hours.abs() <= QualityThresholds.hourOffsetMax &&
            remainder <= QualityThresholds.hourOffsetRemainderToleranceMin) {
          out.add(
            make(
              ctx,
              discriminator: 'src:${s.id}',
              computerId: s.computerId,
              severity: QualitySeverity.warning,
              params: {'offsetHours': hours, 'sourceId': s.id},
            ),
          );
        }
      }
    }

    if (primary != null) out.addAll(_misplacedSources(ctx, primary.id));

    // Same-diver dives overlapping in time cannot both be right.
    final runtime = ctx.dive.effectiveRuntime;
    if (runtime != null) {
      final exit = entry.add(runtime);
      for (final n in ctx.neighbors) {
        final nExit = n.exitTime;
        if (nExit == null) continue;
        if (n.entryTime.isBefore(exit) && nExit.isAfter(entry)) {
          final overlapStart = entry.isAfter(n.entryTime) ? entry : n.entryTime;
          final overlapEnd = exit.isBefore(nExit) ? exit : nExit;
          out.add(
            makePair(
              ctx,
              otherDiveId: n.id,
              discriminator: 'overlap',
              severity: QualitySeverity.warning,
              params: {
                'overlapMinutes': overlapEnd.difference(overlapStart).inMinutes,
              },
            ),
          );
        }
      }
    }
    return out;
  }

  /// Sources placed on the primary's timeline away from where their depth
  /// trace fits the primary's. A consolidation before #4296 trusted any clock
  /// that overlapped the primary, so a clock wrong by less than the dive
  /// lasted left that source's samples shifted by its error.
  List<QualityFinding> _misplacedSources(
    DiveQualityContext ctx,
    String primaryId,
  ) {
    if (ctx.primarySamples.isEmpty) return const [];
    final primaryTrace = [
      for (final q in ctx.primarySamples)
        DiveProfilePoint(timestamp: q.t, depth: q.depth),
    ];
    final primaryStart = ctx.primarySamples.first.t;
    final primaryEnd = ctx.primarySamples.last.t;
    final out = <QualityFinding>[];
    for (final s in ctx.sources) {
      if (s.id == primaryId) continue;
      final samples = ctx.sourceSamples[s.id];
      if (samples == null || samples.isEmpty) continue;
      // Only a source placed over the primary's recording, the case a
      // trusted overlapping clock produced. A later segment of a joined dive
      // sits after it on purpose and may look just like it.
      if (samples.last.t <= primaryStart || samples.first.t >= primaryEnd) {
        continue;
      }
      // The aligner searches around lined-up starts, so the source is moved
      // to its own start first and its placement is measured against that.
      final placedAt = samples.first.t;
      final fit = const ProfileAligner().align(primaryTrace, [
        for (final q in samples)
          DiveProfilePoint(timestamp: q.t - placedAt, depth: q.depth),
      ]);
      if (!fit.isStrongMatch) continue;
      final shift = fit.offsetSeconds - placedAt;
      if (shift.abs() <=
          QualityThresholds.sourceProfileFitTolerance.inSeconds) {
        continue;
      }
      out.add(
        make(
          ctx,
          discriminator: 'fit:${s.id}',
          computerId: s.computerId,
          severity: QualitySeverity.warning,
          params: {'sourceId': s.id, 'profileOffsetSeconds': shift},
        ),
      );
    }
    return out;
  }
}
