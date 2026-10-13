import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_registry.dart';
import 'package:submersion/features/data_quality/domain/detectors/source_alignment_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';
import 'package:submersion/features/dive_log/domain/services/source_alignment_check.dart';

import '../../helpers/quality_test_helpers.dart';

void main() {
  const det = SourceAlignmentDetector();
  final entry = DateTime.utc(2026, 9, 14, 9);

  DiveDataSource source(String id, {bool primary = false}) => DiveDataSource(
    id: id,
    diveId: 'd1',
    computerId: 'comp-$id',
    isPrimary: primary,
    importedAt: entry,
    createdAt: entry,
  );

  SourceAlignmentCheck check(
    String sourceId, {
    required int stored,
    required int fitted,
    bool strong = true,
  }) => SourceAlignmentCheck(
    sourceId: sourceId,
    storedOffsetSeconds: stored,
    fit: ProfileAlignmentResult(
      offsetSeconds: fitted,
      rmsDepthError: strong ? 0.2 : 3,
      overlapFraction: 1,
      usedFallback: false,
      isStrongMatch: strong,
    ),
  );

  List<QualityFinding> run(List<SourceAlignmentCheck> checks) => det.detect(
    makeContext(
      dive: makeTestDive(),
      sources: [source('p', primary: true), source('s')],
      sourceAlignments: checks,
    ),
  );

  test('is registered', () {
    expect(kQualityDetectors.map((d) => d.id), contains(det.id));
  });

  test('a drifted clock is flagged with both offsets', () {
    final findings = run([check('s', stored: 100, fitted: 2)]);
    expect(findings, hasLength(1));
    final f = findings.single;
    expect(f.detectorId, 'source_alignment');
    expect(f.computerId, 'comp-s');
    expect(f.severity, QualitySeverity.warning);
    expect(f.params, {
      'sourceId': 's',
      'storedOffsetSeconds': 100,
      'fittedOffsetSeconds': 2,
    });
  });

  test('agreement within the tolerance is not flagged', () {
    expect(run([check('s', stored: 7, fitted: 2)]), isEmpty);
  });

  test('a weak fit is never flagged', () {
    expect(run([check('s', stored: 100, fitted: 2, strong: false)]), isEmpty);
  });

  test('each misaligned source gets its own finding', () {
    final findings = det.detect(
      makeContext(
        dive: makeTestDive(),
        sources: [source('p', primary: true), source('a'), source('b')],
        sourceAlignments: [
          check('a', stored: 100, fitted: 1),
          check('b', stored: -66, fitted: -166),
        ],
      ),
    );
    expect(findings.map((f) => f.params['sourceId']), ['a', 'b']);
    expect(findings.map((f) => f.id).toSet(), hasLength(2));
  });
}
