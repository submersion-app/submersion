import 'package:drift/drift.dart' show Value;
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

  // Findings carry no diver of their own; the badge and the inbox reach the
  // active diver through the dive a finding names (issue #3049).
  group('scoped to a diver', () {
    Future<void> addDive(String id, String? diverId) => db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: Value(diverId),
            diveDateTime: 1,
            createdAt: 1,
            updatedAt: 1,
          ),
        );

    QualityFinding pairFinding(String a, String b) {
      final pid = qualityPairIdentity(detectorId: 'duplicate', a: a, b: b);
      return QualityFinding(
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
      );
    }

    late QualityFinding crossDiver;

    setUp(() async {
      await addDive('a1', 'alice');
      await addDive('b1', 'bob');
      await addDive('b2', 'bob');
      // a1 < b1, so the cross-diver pair is anchored on Alice's dive and
      // reaches Bob only through its related dive.
      crossDiver = pairFinding('a1', 'b1');
      await repo.applyScanResults(
        scopeDiveIds: {'a1', 'b1', 'b2'},
        ranDetectorIds: {'sample_gap', 'duplicate'},
        produced: [
          finding(diveId: 'a1'),
          finding(diveId: 'b2'),
          crossDiver,
        ],
      );
    });

    test('watchOpenCount counts only that diver\'s dives', () async {
      expect(await repo.watchOpenCount(diverId: 'alice').first, 2);
      expect(await repo.watchOpenCount(diverId: 'bob').first, 2);
      expect(await repo.watchOpenCount(diverId: 'carol').first, 0);
      expect(await repo.watchOpenCount().first, 3);
    });

    test('watchFindings lists only that diver\'s dives', () async {
      Future<List<String>> ids(String? diverId) async => [
        for (final f in await repo.watchFindings(diverId: diverId).first) f.id,
      ];
      expect(
        await ids('alice'),
        unorderedEquals([finding(diveId: 'a1').id, crossDiver.id]),
      );
      // Bob sees his own finding and the pair through its related dive.
      expect(
        await ids('bob'),
        unorderedEquals([finding(diveId: 'b2').id, crossDiver.id]),
      );
      expect(await repo.watchFindings(diverId: 'carol').first, isEmpty);
      expect(await repo.watchFindings().first, hasLength(3));
    });
  });

  // A newer build can sync a finding whose category, severity or status this
  // build does not know; the inbox must still load the rest (issue #2853).
  group('rows this build cannot read', () {
    Future<void> insertRow(String id, {String category = 'time'}) async {
      await db
          .into(db.qualityFindings)
          .insert(
            QualityFindingsCompanion.insert(
              id: id,
              diveId: 'd-unreadable',
              detectorId: 'clock_offset',
              detectorVersion: 1,
              category: category,
              severity: 'info',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }

    setUp(() async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'd-unreadable',
              diveDateTime: 1,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await insertRow('readable');
      await insertRow('from-the-future', category: 'gear');
    });

    test('getFindings skips them', () async {
      final ids = (await repo.getFindings()).map((f) => f.id);
      expect(ids, contains('readable'));
      expect(ids, isNot(contains('from-the-future')));
    });

    test('watchFindings skips them', () async {
      final ids = (await repo.watchFindings().first).map((f) => f.id);
      expect(ids, contains('readable'));
      expect(ids, isNot(contains('from-the-future')));
    });

    // The badge and the dive counts must match what the inbox lists.
    test('the open counts skip them', () async {
      await db
          .into(db.qualityFindings)
          .insert(
            QualityFindingsCompanion.insert(
              id: 'severity-from-the-future',
              diveId: 'd-unreadable',
              detectorId: 'clock_offset',
              detectorVersion: 1,
              category: 'time',
              severity: 'fatal',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      expect(await repo.watchOpenCount().first, 1);
      expect(await repo.watchOpenCountForDive('d-unreadable').first, 1);
      expect(await repo.watchOpenCountForDives({'d-unreadable'}).first, 1);
    });
  });
}
