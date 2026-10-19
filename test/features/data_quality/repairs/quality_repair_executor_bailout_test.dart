import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_repair_executor.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import '../../../helpers/global_test_defaults.dart';
import '../../../helpers/test_database.dart';

/// Issue #3307: the "Use as bailout" repair on a transmitter_role finding.
void main() {
  late AppDatabase db;
  late QualityFindingsRepository findingsRepo;
  late QualityRepairExecutor executor;

  setUp(() async {
    await setUpTestDatabase();
    QualityScanScheduler.enabled = false;
    db = DatabaseService.instance.database;
    findingsRepo = QualityFindingsRepository();
    executor = QualityRepairExecutor();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'A', 1, 1)",
    );
    for (final id in ['d1', 'd2']) {
      await DiveRepository().createDive(
        domain.Dive(
          id: id,
          diverId: 'diver-1',
          dateTime: DateTime.utc(2026, 7, id == 'd1' ? 1 : 2, 10),
          diveMode: DiveMode.ccr,
        ),
      );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: Value('tx-$id'),
              diveId: Value(id),
              tankOrder: const Value(0),
              sourceTankIndex: const Value(0),
              tankRole: const Value('oxygenSupply'),
              roleSource: const Value('transmitterName'),
              o2Percent: const Value(100),
              transmitterSerial: const Value('180777'),
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: Value('oc-$id'),
              diveId: Value(id),
              tankOrder: const Value(3),
              sourceTankIndex: const Value(3),
              tankRole: const Value('bailout'),
              o2Percent: const Value(18),
              hePercent: const Value(45),
            ),
          );
    }
  });
  tearDown(() {
    applyGlobalTestDefaults();
    return tearDownTestDatabase();
  });

  Future<QualityFinding> seedFinding() async {
    final finding = QualityFinding(
      id: qualityFindingId(
        diveId: 'd1',
        detectorId: 'transmitter_role',
        discriminator: 'tx-d1',
      ),
      diveId: 'd1',
      detectorId: 'transmitter_role',
      detectorVersion: 1,
      category: QualityCategory.tank,
      severity: QualitySeverity.warning,
      status: QualityStatus.open,
      params: const {'tankId': 'tx-d1', 'ocTankId': 'oc-d1'},
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );
    await findingsRepo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'transmitter_role'},
      produced: [finding],
    );
    return finding;
  }

  Future<DiveTank?> row(String id) => (db.select(
    db.diveTanks,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  test('useAsBailout without registering resolves the finding and undo '
      'restores', () async {
    final finding = await seedFinding();

    final outcome = await executor.useAsBailout(
      diveId: 'd1',
      tankId: 'tx-d1',
      ocTankId: 'oc-d1',
      findingId: finding.id,
      registerTransmitter: false,
    );

    expect(outcome.result.changed, isTrue);
    final tx = (await row('tx-d1'))!;
    expect(tx.tankRole, 'bailout');
    expect(tx.o2Percent, 18);
    expect(await row('oc-d1'), isNull);
    expect((await row('tx-d2'))!.tankRole, 'oxygenSupply');
    final findings = await findingsRepo.getFindings(diveId: 'd1');
    expect(findings.single.status, QualityStatus.resolved);

    await outcome.result.undo!();
    expect((await row('tx-d1'))!.tankRole, 'oxygenSupply');
    expect((await row('tx-d1'))!.o2Percent, 100);
    expect(await row('oc-d1'), isNotNull);
  });

  test('useAsBailout with registering creates a bailout registry entry and '
      'applies it to other dives', () async {
    final finding = await seedFinding();

    final outcome = await executor.useAsBailout(
      diveId: 'd1',
      tankId: 'tx-d1',
      ocTankId: 'oc-d1',
      findingId: finding.id,
      registerTransmitter: true,
      serial: '180777',
      label: 'OC',
      diverId: 'diver-1',
    );

    final entries = await TransmitterRepository().getForDiver('diver-1');
    expect(entries.single.role, TankRole.bailout);
    expect(entries.single.transmitterSerial, '180777');
    final tx2 = (await row('tx-d2'))!;
    expect(tx2.tankRole, 'bailout');
    expect(tx2.o2Percent, 18);
    expect(await row('oc-d2'), isNull);
    expect(outcome.mixesKept, 0);
  });

  test('registering updates an existing entry\'s role', () async {
    final repo = TransmitterRepository();
    await repo.create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '180777',
        label: 'OC',
        createdAt: DateTime.utc(2026, 7, 1),
        updatedAt: DateTime.utc(2026, 7, 1),
      ),
    );
    final finding = await seedFinding();

    await executor.useAsBailout(
      diveId: 'd1',
      tankId: 'tx-d1',
      ocTankId: 'oc-d1',
      findingId: finding.id,
      registerTransmitter: true,
      serial: '180777',
      label: 'OC',
      diverId: 'diver-1',
    );

    final entries = await repo.getForDiver('diver-1');
    expect(entries, hasLength(1));
    expect(entries.single.id, 'e1');
    expect(entries.single.role, TankRole.bailout);
  });

  // Review: the report must not claim a registration that did not happen.
  test('registering without a serial registers nothing and says so', () async {
    final finding = await seedFinding();

    final outcome = await executor.useAsBailout(
      diveId: 'd1',
      tankId: 'tx-d1',
      ocTankId: 'oc-d1',
      findingId: finding.id,
      registerTransmitter: true,
      diverId: 'diver-1',
    );

    expect(outcome.registered, isFalse);
    expect(await TransmitterRepository().getForDiver('diver-1'), isEmpty);
  });

  // Review: once this dive is repaired, a registry failure must not take
  // the undo away or leave the finding open.
  test(
    'a registry failure still resolves the finding and keeps undo',
    () async {
      final finding = await seedFinding();
      final failing = QualityRepairExecutor(
        transmitterRepository: _ThrowingTransmitterRepository(),
      );

      final outcome = await failing.useAsBailout(
        diveId: 'd1',
        tankId: 'tx-d1',
        ocTankId: 'oc-d1',
        findingId: finding.id,
        registerTransmitter: true,
        serial: '180777',
        diverId: 'diver-1',
      );

      expect(outcome.result.changed, isTrue);
      expect(outcome.result.undo, isNotNull);
      expect(outcome.registered, isFalse);
      final findings = await findingsRepo.getFindings(diveId: 'd1');
      expect(findings.single.status, QualityStatus.resolved);
    },
  );

  // Review: a transmitter breathed as a deco gas is registered as Deco, the
  // role the repair gave it, not as Bailout.
  test('registers the role the repair chose', () async {
    await (db.update(db.diveTanks)..where((t) => t.id.equals('oc-d1'))).write(
      const DiveTanksCompanion(
        tankRole: Value('deco'),
        o2Percent: Value(100),
        hePercent: Value(0),
      ),
    );
    final finding = await seedFinding();

    final outcome = await executor.useAsBailout(
      diveId: 'd1',
      tankId: 'tx-d1',
      ocTankId: 'oc-d1',
      findingId: finding.id,
      registerTransmitter: true,
      serial: '180777',
      label: 'O2',
      diverId: 'diver-1',
    );

    expect(outcome.role, TankRole.deco);
    final entries = await TransmitterRepository().getForDiver('diver-1');
    expect(entries.single.role, TankRole.deco);
  });
}

class _ThrowingTransmitterRepository extends TransmitterRepository {
  @override
  Future<List<Transmitter>> getForDiver(String? diverId) async =>
      throw StateError('registry unavailable');
}
