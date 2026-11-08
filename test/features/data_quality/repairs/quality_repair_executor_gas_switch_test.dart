import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_repair_executor.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

import '../../../helpers/global_test_defaults.dart';
import '../../../helpers/test_database.dart';

/// Issue #165: the missing-switch finding's one-tap repair.
void main() {
  late DiveRepository diveRepo;
  late QualityFindingsRepository findingsRepo;
  late QualityRepairExecutor executor;

  setUp(() async {
    await setUpTestDatabase();
    // The executor queues a targeted rescan; keep it out of the test zone.
    QualityScanScheduler.enabled = false;
    diveRepo = DiveRepository();
    findingsRepo = QualityFindingsRepository();
    executor = QualityRepairExecutor();
  });
  tearDown(() {
    applyGlobalTestDefaults();
    return tearDownTestDatabase();
  });

  Future<QualityFinding> seedDiveAndFinding() async {
    await diveRepo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 7, 1),
        tanks: const [
          domain.DiveTank(id: 'back', order: 0),
          domain.DiveTank(id: 'deco', order: 1),
          domain.DiveTank(id: 'o2', order: 2),
        ],
      ),
    );
    final finding = QualityFinding(
      id: qualityFindingId(diveId: 'd1', detectorId: 'missing_gas_switch'),
      diveId: 'd1',
      detectorId: 'missing_gas_switch',
      detectorVersion: 1,
      category: QualityCategory.tank,
      severity: QualitySeverity.warning,
      status: QualityStatus.open,
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );
    await findingsRepo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'missing_gas_switch'},
      produced: [finding],
    );
    return finding;
  }

  Future<bool> switchesEdited() async {
    final db = DatabaseService.instance.database;
    final dive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('d1'))).getSingle();
    return dive.gasSwitchesEdited;
  }

  Future<QualityStatus> statusOf(String findingId) async =>
      (await findingsRepo.getFindings(
        diveId: 'd1',
      )).singleWhere((f) => f.id == findingId).status;

  test('adds every switch, resolves the finding, and undo removes them '
      'again', () async {
    final finding = await seedDiveAndFinding();

    final result = await executor.addGasSwitches(
      diveId: 'd1',
      switches: const [
        (tankId: 'deco', t: 1800, depth: 21.0),
        (tankId: 'o2', t: 2700, depth: 6.0),
      ],
      findingId: finding.id,
    );

    expect(result.changed, isTrue);
    final added = await diveRepo.getGasSwitchesForDive('d1');
    expect(
      [
        for (final s in added)
          (s.gasSwitch.tankId, s.gasSwitch.timestamp, s.gasSwitch.depth),
      ],
      [('deco', 1800, 21.0), ('o2', 2700, 6.0)],
    );
    // Like a switch typed in the editor, it applies to every computer.
    expect([for (final s in added) s.gasSwitch.computerId], [null, null]);
    expect(await statusOf(finding.id), QualityStatus.resolved);
    // Written as the editor writes: the list is now the diver's, so a
    // re-parse or file resync leaves it alone.
    expect(await switchesEdited(), isTrue);

    await result.undo!();
    expect(await diveRepo.getGasSwitchesForDive('d1'), isEmpty);
    expect(await switchesEdited(), isFalse);
  });

  test('undo keeps a list the diver already owned as theirs', () async {
    final finding = await seedDiveAndFinding();
    final db = DatabaseService.instance.database;
    await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
      const DivesCompanion(gasSwitchesEdited: Value(true)),
    );

    final result = await executor.addGasSwitches(
      diveId: 'd1',
      switches: const [(tankId: 'deco', t: 1800, depth: 21.0)],
      findingId: finding.id,
    );
    await result.undo!();

    expect(await switchesEdited(), isTrue);
  });

  test('changes nothing once the dive has a switch of its own', () async {
    final finding = await seedDiveAndFinding();
    await diveRepo.createGasSwitch(
      GasSwitch(
        id: 'typed',
        diveId: 'd1',
        timestamp: 1750,
        tankId: 'deco',
        createdAt: DateTime.utc(2026, 7, 2),
      ),
    );

    final result = await executor.addGasSwitches(
      diveId: 'd1',
      switches: const [(tankId: 'deco', t: 1800, depth: 21.0)],
      findingId: finding.id,
    );

    expect(result.changed, isFalse);
    expect(
      [
        for (final s in await diveRepo.getGasSwitchesForDive('d1'))
          s.gasSwitch.id,
      ],
      ['typed'],
    );
    expect(await statusOf(finding.id), QualityStatus.open);
  });

  test('undo leaves a switch added after the repair alone', () async {
    final finding = await seedDiveAndFinding();
    final result = await executor.addGasSwitches(
      diveId: 'd1',
      switches: const [(tankId: 'deco', t: 1800, depth: 21.0)],
      findingId: finding.id,
    );
    await diveRepo.createGasSwitch(
      GasSwitch(
        id: 'later',
        diveId: 'd1',
        timestamp: 2700,
        tankId: 'o2',
        createdAt: DateTime.utc(2026, 7, 2),
      ),
    );

    await result.undo!();

    expect(
      [
        for (final s in await diveRepo.getGasSwitchesForDive('d1'))
          s.gasSwitch.id,
      ],
      ['later'],
    );
  });

  test('changes nothing when a cylinder it names has left the dive', () async {
    final finding = await seedDiveAndFinding();

    final result = await executor.addGasSwitches(
      diveId: 'd1',
      switches: const [
        (tankId: 'deco', t: 1800, depth: 21.0),
        (tankId: 'gone', t: 2700, depth: 6.0),
      ],
      findingId: finding.id,
    );

    expect(result.changed, isFalse);
    expect(await diveRepo.getGasSwitchesForDive('d1'), isEmpty);
    expect(await statusOf(finding.id), QualityStatus.open);
  });
}
