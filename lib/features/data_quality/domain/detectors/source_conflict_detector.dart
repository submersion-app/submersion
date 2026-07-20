import 'dart:math' as math;

import 'package:collection/collection.dart';

import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';

class SourceConflictDetector extends QualityDetector {
  const SourceConflictDetector();

  @override
  String get id => 'source_conflict';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.source;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final sources = ctx.sources;
    if (sources.length < 2) return const [];
    final primary =
        sources.firstWhereOrNull((s) => s.isPrimary) ?? sources.first;
    final out = <QualityFinding>[];

    for (final s in sources) {
      if (s.id == primary.id) continue;

      final pd = primary.maxDepth;
      final sd = s.maxDepth;
      if (pd != null && sd != null && pd > 0) {
        final diff = (pd - sd).abs();
        final tol = math.max(
          QualityThresholds.sourceDepthDiffMinMeters,
          pd * QualityThresholds.sourceDepthDiffFraction,
        );
        if (diff > tol) {
          final ratio = sd / pd;
          out.add(
            make(
              ctx,
              discriminator: 'depth:${s.id}',
              computerId: s.computerId,
              severity: QualitySeverity.warning,
              params: {
                'sourceId': s.id,
                'primaryMaxDepth': pd,
                'sourceMaxDepth': sd,
                'depthRatio': ratio,
                'salinitySettingSuspected':
                    ratio >= QualityThresholds.salinityRatioLow &&
                    ratio <= QualityThresholds.salinityRatioHigh,
              },
            ),
          );
        }
      }

      final pdur = primary.duration;
      final sdur = s.duration;
      if (pdur != null &&
          sdur != null &&
          pdur > 0 &&
          (pdur - sdur).abs() >
              pdur * QualityThresholds.sourceDurationDiffFraction) {
        out.add(
          make(
            ctx,
            discriminator: 'duration:${s.id}',
            computerId: s.computerId,
            severity: QualitySeverity.info,
            params: {
              'sourceId': s.id,
              'primarySeconds': pdur,
              'sourceSeconds': sdur,
            },
          ),
        );
      }

      final pt = primary.waterTemp;
      final st = s.waterTemp;
      if (pt != null &&
          st != null &&
          (pt - st).abs() > QualityThresholds.sourceTempDiffC) {
        out.add(
          make(
            ctx,
            discriminator: 'temp:${s.id}',
            computerId: s.computerId,
            severity: QualitySeverity.info,
            params: {'sourceId': s.id, 'primaryTempC': pt, 'sourceTempC': st},
          ),
        );
      }
    }
    return out;
  }
}
