import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';

import '../../../helpers/test_database.dart';

QualityFinding finding({
  String diveId = 'd1',
  String detectorId = 'sample_gap',
  String discriminator = '',
  QualitySeverity severity = QualitySeverity.info,
  Map<String, Object?> params = const {'gapCount': 1},
}) {
  final now = DateTime.utc(2026, 7, 17);
  return QualityFinding(
    id: qualityFindingId(
      diveId: diveId,
      detectorId: detectorId,
      discriminator: discriminator,
    ),
    diveId: diveId,
    detectorId: detectorId,
    detectorVersion: 1,
    category: QualityCategory.profile,
    severity: severity,
    status: QualityStatus.open,
    params: params,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late AppDatabase db;
  late QualityFindingsRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    // Findings reference dives; FK seeding is out of scope for these tests.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repo = QualityFindingsRepository();
  });
  tearDown(tearDownTestDatabase);

  test('applyScanResults inserts new findings as open', () async {
    final result = await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: [finding()],
    );
    expect(result.inserted, 1);
    final all = await repo.getFindings();
    expect(all, hasLength(1));
    expect(all.single.status, QualityStatus.open);
  });

  test('rescan preserves dismissed status', () async {
    final f = finding();
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: [f],
    );
    await repo.setStatus(f.id, QualityStatus.dismissed);
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: [
        f.copyWith(params: const {'gapCount': 3}),
      ],
    );
    final all = await repo.getFindings();
    expect(all.single.status, QualityStatus.dismissed);
    expect(all.single.params['gapCount'], 3); // facts refresh, status sticks
  });

  test('resolved finding still produced is reopened', () async {
    final f = finding();
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: [f],
    );
    await repo.setStatus(f.id, QualityStatus.resolved);
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: [f],
    );
    final all = await repo.getFindings();
    expect(all.single.status, QualityStatus.open);
  });

  test('finding not re-produced is deleted with a tombstone', () async {
    final f = finding();
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: [f],
    );
    final result = await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: const [],
    );
    expect(result.removed, 1);
    expect(await repo.getFindings(), isEmpty);
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'qualityFindings'",
        )
        .get();
    expect(tombstones.map((r) => r.read<String>('record_id')), contains(f.id));
  });

  test('detectors that did not run leave their findings untouched', () async {
    final gap = finding();
    final spike = finding(detectorId: 'depth_spike');
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap', 'depth_spike'},
      produced: [gap, spike],
    );
    // Rescan runs only sample_gap and produces nothing: the spike finding
    // must survive.
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: const [],
    );
    final all = await repo.getFindings();
    expect(all.map((f) => f.detectorId), ['depth_spike']);
  });

  test('pair findings retire when either member is in scope', () async {
    final pid = qualityPairIdentity(detectorId: 'duplicate', a: 'dB', b: 'dA');
    final pair = QualityFinding(
      id: pid.id,
      diveId: pid.diveId, // 'dA'
      relatedDiveId: pid.relatedDiveId, // 'dB'
      detectorId: 'duplicate',
      detectorVersion: 1,
      category: QualityCategory.duplicate,
      severity: QualitySeverity.warning,
      status: QualityStatus.open,
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );
    await repo.applyScanResults(
      scopeDiveIds: {'dA', 'dB'},
      ranDetectorIds: {'duplicate'},
      produced: [pair],
    );
    // Scanning only dB (the related dive) and producing nothing retires it.
    await repo.applyScanResults(
      scopeDiveIds: {'dB'},
      ranDetectorIds: {'duplicate'},
      produced: const [],
    );
    expect(await repo.getFindings(), isEmpty);
  });

  test('watchOpenCount tracks open findings', () async {
    final f = finding();
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap'},
      produced: [f],
    );
    expect(await repo.watchOpenCount().first, 1);
    await repo.setStatus(f.id, QualityStatus.dismissed);
    expect(await repo.watchOpenCount().first, 0);
  });
}
