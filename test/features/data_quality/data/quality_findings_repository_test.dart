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

  test('dismissAll dismisses every id with one call', () async {
    final a = finding();
    final b = finding(detectorId: 'depth_spike');
    await repo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'sample_gap', 'depth_spike'},
      produced: [a, b],
    );
    await repo.dismissAll([a.id, b.id]);
    final all = await repo.getFindings();
    expect(all.map((f) => f.status).toSet(), {QualityStatus.dismissed});
  });

  test('watchOpenCountForDive matches diveId or relatedDiveId', () async {
    final pid = qualityPairIdentity(detectorId: 'duplicate', a: 'dX', b: 'dY');
    await repo.applyScanResults(
      scopeDiveIds: {'dX', 'dY'},
      ranDetectorIds: {'duplicate'},
      produced: [
        QualityFinding(
          id: pid.id,
          diveId: pid.diveId,
          relatedDiveId: pid.relatedDiveId,
          detectorId: 'duplicate',
          detectorVersion: 1,
          category: QualityCategory.duplicate,
          severity: QualitySeverity.warning,
          status: QualityStatus.open,
          createdAt: DateTime.utc(2026, 7, 17),
          updatedAt: DateTime.utc(2026, 7, 17),
        ),
      ],
    );
    expect(await repo.watchOpenCountForDive('dY').first, 1);
  });

  test('watchOpenCountForDives is empty for an empty id set', () async {
    expect(await repo.watchOpenCountForDives(const {}).first, 0);
  });

  test(
    'watchOpenCountForDives counts diveId or relatedDiveId in the set',
    () async {
      // d1: scalar finding; dP<->dQ: a pair anchored on dP with related dQ.
      final scalar = finding(diveId: 'd1');
      final pid = qualityPairIdentity(
        detectorId: 'duplicate',
        a: 'dP',
        b: 'dQ',
      );
      final pair = QualityFinding(
        id: pid.id,
        diveId: pid.diveId, // 'dP'
        relatedDiveId: pid.relatedDiveId, // 'dQ'
        detectorId: 'duplicate',
        detectorVersion: 1,
        category: QualityCategory.duplicate,
        severity: QualitySeverity.warning,
        status: QualityStatus.open,
        createdAt: DateTime.utc(2026, 7, 17),
        updatedAt: DateTime.utc(2026, 7, 17),
      );
      // dOut's finding is outside every queried set and must never count.
      final outside = finding(diveId: 'dOut');
      await repo.applyScanResults(
        scopeDiveIds: {'d1', 'dP', 'dQ', 'dOut'},
        ranDetectorIds: {'sample_gap', 'duplicate'},
        produced: [scalar, pair, outside],
      );

      // Reaches the pair via its related dive only.
      expect(await repo.watchOpenCountForDives({'dQ'}).first, 1);
      // Union across the set: scalar + pair, dOut excluded.
      expect(await repo.watchOpenCountForDives({'d1', 'dP'}).first, 2);

      // Dismissed findings drop out of the open count.
      await repo.setStatus(scalar.id, QualityStatus.dismissed);
      expect(await repo.watchOpenCountForDives({'d1', 'dP'}).first, 1);
    },
  );
}
