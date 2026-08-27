import 'package:flutter/foundation.dart';

import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';

/// A pure, synchronous quality check. Implementations must not do IO and
/// must read every threshold from QualityThresholds.
abstract class QualityDetector {
  const QualityDetector();

  String get id;

  /// Bump when detection logic changes; drives "new checks available".
  int get version;
  QualityCategory get category;

  List<QualityFinding> detect(DiveQualityContext context);

  @protected
  QualityFinding make(
    DiveQualityContext ctx, {
    String discriminator = '',
    String? relatedDiveId,
    String? computerId,
    required QualitySeverity severity,
    Map<String, Object?> params = const {},
  }) => QualityFinding(
    id: qualityFindingId(
      diveId: ctx.dive.id,
      detectorId: id,
      discriminator: discriminator,
    ),
    diveId: ctx.dive.id,
    relatedDiveId: relatedDiveId,
    computerId: computerId,
    detectorId: id,
    detectorVersion: version,
    category: category,
    severity: severity,
    status: QualityStatus.open,
    params: params,
    createdAt: ctx.now,
    updatedAt: ctx.now,
  );

  /// Cross-dive finding anchored on the lexically smaller dive id so both
  /// members' scans produce the identical row.
  @protected
  QualityFinding makePair(
    DiveQualityContext ctx, {
    required String otherDiveId,
    String discriminator = '',
    String? computerId,
    required QualitySeverity severity,
    Map<String, Object?> params = const {},
  }) {
    final pid = qualityPairIdentity(
      detectorId: id,
      a: ctx.dive.id,
      b: otherDiveId,
      discriminator: discriminator,
    );
    return QualityFinding(
      id: pid.id,
      diveId: pid.diveId,
      relatedDiveId: pid.relatedDiveId,
      computerId: computerId,
      detectorId: id,
      detectorVersion: version,
      category: category,
      severity: severity,
      status: QualityStatus.open,
      params: params,
      createdAt: ctx.now,
      updatedAt: ctx.now,
    );
  }
}
