import 'package:collection/collection.dart';

import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';

class ClockOffsetDetector extends QualityDetector {
  const ClockOffsetDetector();

  @override
  String get id => 'clock_offset';
  @override
  int get version => 1;
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
}
