import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';

void main() {
  test('qualityFindingId is deterministic and discriminator-sensitive', () {
    final a = qualityFindingId(diveId: 'd1', detectorId: 'depth_spike');
    final b = qualityFindingId(diveId: 'd1', detectorId: 'depth_spike');
    final c = qualityFindingId(
      diveId: 'd1',
      detectorId: 'depth_spike',
      discriminator: 'spike:4',
    );
    expect(a, b);
    expect(a, isNot(c));
    expect(a, matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  test('qualityPairIdentity is order-independent', () {
    final p1 = qualityPairIdentity(detectorId: 'duplicate', a: 'dA', b: 'dB');
    final p2 = qualityPairIdentity(detectorId: 'duplicate', a: 'dB', b: 'dA');
    expect(p1.id, p2.id);
    expect(p1.diveId, 'dA'); // lexically smaller id is the anchor
    expect(p1.relatedDiveId, 'dB');
  });

  test('enums round-trip by name', () {
    expect(QualityStatus.values.byName('dismissed'), QualityStatus.dismissed);
    expect(QualityCategory.values.byName('source'), QualityCategory.source);
    expect(QualitySeverity.values.byName('critical'), QualitySeverity.critical);
  });

  test('copyWith replaces only what is passed', () {
    final f = QualityFinding(
      id: 'id1',
      diveId: 'd1',
      detectorId: 'sample_gap',
      detectorVersion: 1,
      category: QualityCategory.profile,
      severity: QualitySeverity.info,
      status: QualityStatus.open,
      params: const {'gapCount': 2},
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );
    final g = f.copyWith(status: QualityStatus.dismissed);
    expect(g.status, QualityStatus.dismissed);
    expect(g.diveId, 'd1');
    expect(g.params, const {'gapCount': 2});
  });
}
