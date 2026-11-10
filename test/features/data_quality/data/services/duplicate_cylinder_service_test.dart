import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/change_log/data/services/change_log_operation_undo.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/duplicate_cylinder_service.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/data/repositories/duplicate_cylinder_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/global_test_defaults.dart';
import '../../../../helpers/test_database.dart';

/// A merge that fails on one dive, to prove a batch survives it.
class _FailingOn extends DuplicateCylinderRepository {
  _FailingOn(this.diveId);
  final String diveId;

  @override
  Future<bool> mergeInto({
    required String diveId,
    required String survivorId,
    required List<String> duplicateIds,
    ({double o2, double he})? mix,
    required int now,
  }) {
    if (diveId == this.diveId) throw StateError('disk full');
    return super.mergeInto(
      diveId: diveId,
      survivorId: survivorId,
      duplicateIds: duplicateIds,
      mix: mix,
      now: now,
    );
  }
}

/// A findings repository whose bulk resolve fails.
class _ResolveFails extends QualityFindingsRepository {
  @override
  Future<void> resolveAll(Iterable<String> ids) async =>
      throw StateError('database is locked');
}

/// Removing duplicate cylinders on one dive or many (issue #4393).
void main() {
  late AppDatabase db;
  late QualityFindingsRepository findings;
  late DuplicateCylinderService service;

  Future<void> insertTank(
    String id,
    String diveId, {
    String? serial,
    double o2 = 32,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(
          id: id,
          diveId: diveId,
          o2Percent: Value(o2),
          transmitterSerial: Value(serial),
        ),
      );

  QualityFinding twin(
    String diveId,
    String a,
    String b, {
    required bool sameTransmitter,
  }) => QualityFinding(
    id: qualityFindingId(
      diveId: diveId,
      detectorId: 'tank_assignment',
      discriminator: 'twin:$a|$b',
    ),
    diveId: diveId,
    detectorId: 'tank_assignment',
    detectorVersion: 3,
    category: QualityCategory.tank,
    severity: QualitySeverity.warning,
    status: QualityStatus.open,
    params: {
      'tankIdA': a,
      'tankIdB': b,
      'meanDiffBar': 0.0,
      'sameTransmitter': sameTransmitter,
    },
    createdAt: DateTime.utc(2026, 11, 9),
    updatedAt: DateTime.utc(2026, 11, 9),
  );

  Future<List<QualityFinding>> seed(List<QualityFinding> produced) async {
    await findings.applyScanResults(
      scopeDiveIds: {for (final f in produced) f.diveId},
      ranDetectorIds: {'tank_assignment'},
      produced: produced,
    );
    return produced;
  }

  Future<Set<String>> tankIds(String diveId) async => {
    for (final t in await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals(diveId))).get())
      t.id,
  };

  Future<QualityStatus> statusOf(String id) async =>
      (await findings.getFindings()).singleWhere((f) => f.id == id).status;

  setUp(() async {
    db = await setUpTestDatabase();
    QualityScanScheduler.enabled = false;
    findings = QualityFindingsRepository();
    service = DuplicateCylinderService();
    await insertDiver(db, 'me');
    for (final d in ['d1', 'd2', 'd3', 'd4']) {
      await insertDive(db, d, diverId: 'me');
    }
    // d1: three rows on one transmitter.
    await insertTank('a1', 'd1', serial: 'X1');
    await insertTank('b1', 'd1', serial: 'X1');
    await insertTank('c1', 'd1', serial: 'X1');
    // d2: one transmitter, two mixes.
    await insertTank('a2', 'd2', serial: 'Y2', o2: 32);
    await insertTank('b2', 'd2', serial: 'Y2', o2: 21);
    // d3: matched by curves only.
    await insertTank('a3', 'd3');
    await insertTank('b3', 'd3');
  });

  tearDown(() async {
    applyGlobalTestDefaults();
    await tearDownTestDatabase();
  });

  List<QualityFinding> allFindings() => [
    twin('d1', 'a1', 'b1', sameTransmitter: true),
    twin('d1', 'a1', 'c1', sameTransmitter: true),
    twin('d1', 'b1', 'c1', sameTransmitter: true),
    twin('d2', 'a2', 'b2', sameTransmitter: true),
    twin('d3', 'a3', 'b3', sameTransmitter: false),
    // d4's cylinders were merged since the scan.
    twin('d4', 'a4', 'b4', sameTransmitter: true),
  ];

  test('bulk candidates are serial-proven twins only', () {
    final candidates = service.bulkCandidates(allFindings());

    expect(candidates.map((f) => f.diveId), ['d1', 'd1', 'd1', 'd2', 'd4']);
  });

  test('three tanks on one serial merge in one run and resolve all three '
      'findings', () async {
    final seeded = await seed(allFindings());
    final previews = await service.previewAll(service.bulkCandidates(seeded));

    final d1 = previews.singleWhere((p) => p.diveId == 'd1');
    expect(d1.survivorId, 'a1');
    expect(d1.duplicateIds, ['b1', 'c1']);

    final result = await service.removeAll(previews);

    expect(result.merged, 1);
    expect(await tankIds('d1'), {'a1'});
    for (final f in seeded.where((f) => f.diveId == 'd1')) {
      expect(await statusOf(f.id), QualityStatus.resolved);
    }
  });

  test(
    'dives whose mixes differ are skipped and their findings stay open',
    () async {
      final seeded = await seed(allFindings());
      final previews = await service.previewAll(service.bulkCandidates(seeded));

      final result = await service.removeAll(previews);

      expect(result.skippedMixes, 1);
      expect(await tankIds('d2'), {'a2', 'b2'});
      final d2 = seeded.singleWhere((f) => f.diveId == 'd2');
      expect(await statusOf(d2.id), QualityStatus.open);
    },
  );

  test('a stale finding is skipped without counting a failure', () async {
    final seeded = await seed(allFindings());
    final previews = await service.previewAll(service.bulkCandidates(seeded));

    expect(previews.where((p) => p.diveId == 'd4'), isEmpty);
    final result = await service.removeAll(previews);
    expect(result.failed, 0);
  });

  test('one failing dive does not stop the batch', () async {
    await insertTank('a5', 'd3', serial: 'Z5');
    await insertTank('b5', 'd3', serial: 'Z5');
    final seeded = await seed([
      ...allFindings(),
      twin('d3', 'a5', 'b5', sameTransmitter: true),
    ]);
    final failing = DuplicateCylinderService(repository: _FailingOn('d1'));
    final previews = await failing.previewAll(failing.bulkCandidates(seeded));

    final result = await failing.removeAll(previews);

    expect(result.failed, 1);
    expect(result.merged, 1);
    expect(await tankIds('d3'), containsAll(['a5', 'a3', 'b3']));
    expect(await tankIds('d3'), isNot(contains('b5')));
  });

  test(
    'a failure to resolve findings does not hide the merges that landed',
    () async {
      final seeded = await seed(allFindings());
      final quiet = DuplicateCylinderService(findings: _ResolveFails());
      final previews = await quiet.previewAll(quiet.bulkCandidates(seeded));

      final result = await quiet.removeAll(previews);

      expect(result.merged, 1);
      expect(result.failed, 0);
      expect(await tankIds('d1'), {'a1'});
    },
  );

  test('the whole batch reverts with one undo', () async {
    final pressureOnB1 = await TankPressureSeriesRepository().insertSeries(
      diveId: 'd1',
      tankId: 'b1',
      computerId: null,
      samples: const [TankPressureSample(timestamp: 0, pressure: 200)],
      now: 1000,
    );
    final seeded = await seed(allFindings());
    final previews = await service.previewAll(service.bulkCandidates(seeded));
    final result = await service.removeAll(previews);
    expect(result.operationId, isNotNull);

    final undone = await undoChangeLogOperation(
      result.operationId,
      revert: ChangeLogRevertService(afterDiveWrites: (_) {}),
    );

    expect(undone, isTrue);
    expect(await tankIds('d1'), {'a1', 'b1', 'c1'});
    final series = await (db.select(
      db.tankPressureSeries,
    )..where((s) => s.id.equals(pressureOnB1))).getSingle();
    expect(series.tankId, 'b1');
  });

  test(
    'cylinders are numbered by position and named as the card names them',
    () async {
      await db.customStatement(
        "UPDATE dive_tanks SET tank_order = 0 WHERE id = 'a2'",
      );
      await db.customStatement(
        "UPDATE dive_tanks SET tank_order = 5, tank_name = ' ', "
        "preset_name = 'AL80' WHERE id = 'b2'",
      );
      final seeded = await seed(allFindings());
      final finding = seeded.singleWhere((f) => f.diveId == 'd2');

      final preview = (await service.previewFor(finding))!;

      final byId = {for (final c in preview.cylinders) c.id: c};
      expect(byId['a2']!.number, 1);
      expect(byId['b2']!.number, 2);
      expect(byId['b2']!.name, isNull);
    },
  );

  test('two serial groups on one dive count as one dive', () async {
    await insertTank('a6', 'd3', serial: 'S6');
    await insertTank('b6', 'd3', serial: 'S6');
    await insertTank('a7', 'd3', serial: 'S7');
    await insertTank('b7', 'd3', serial: 'S7');
    final seeded = await seed([
      twin('d3', 'a6', 'b6', sameTransmitter: true),
      twin('d3', 'a7', 'b7', sameTransmitter: true),
    ]);
    final previews = await service.previewAll(service.bulkCandidates(seeded));
    expect(previews, hasLength(2));

    final result = await service.removeAll(previews);

    expect(result.merged, 1);
    expect(result.diveIds, ['d3']);
  });

  test('a single twin merges its group with the chosen mix', () async {
    final seeded = await seed(allFindings());
    final finding = seeded.singleWhere((f) => f.diveId == 'd2');

    final preview = (await service.previewFor(finding))!;
    expect(preview.mixesDiffer, isTrue);
    final result = await service.removeOne(preview, mix: (o2: 21, he: 0));

    expect(result.merged, 1);
    final kept = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('a2'))).getSingle();
    expect(kept.o2Percent, 21);
    expect(await tankIds('d2'), {'a2'});
    expect(await statusOf(finding.id), QualityStatus.resolved);
  });
}
