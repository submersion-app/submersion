import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import '../../../../helpers/global_test_defaults.dart';
import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// A transmitter item's serial feeds the stored gear-serial mismatch
/// finding (issue #3367), so an agent's serial fix rescans its dives, as
/// the edit page's save does.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  final now = DateTime.utc(2026, 9, 1);

  Future<Set<String>> openDetectors() async => {
    for (final f in await QualityFindingsRepository().getFindings(
      diveId: 'scan',
      status: QualityStatus.open,
    ))
      f.detectorId,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    QualityScanScheduler.enabled = true;
    addTearDown(applyGlobalTestDefaults);
    h = ChildWriteHarness(db);
    await h.seed();
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'tx',
            name: 'Tx',
            type: 'transmitter',
            createdAt: kSeedTime,
            updatedAt: kSeedTime,
            diverId: const Value(kDiverA),
            serialNumber: const Value('999'),
          ),
        );
    final entry = DateTime.utc(2026, 7, 1, 10);
    await DiveRepository().createDive(
      domain.Dive(
        id: 'scan',
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 40),
        maxDepth: 30,
        diverId: kDiverA,
        tanks: const [
          domain.DiveTank(
            id: 't1',
            gasMix: domain.GasMix(o2: 21, he: 0),
            transmitterSerial: '555',
          ),
        ],
      ),
    );
    await TransmitterRepository().create(
      Transmitter(
        id: 'e1',
        diverId: kDiverA,
        transmitterSerial: '555',
        label: 'Main',
        transmitterEquipmentId: 'tx',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await QualityScanScheduler.instance.idle;
  });
  tearDown(() => tearDownTestDatabase());

  test('fixing a transmitter item\'s serial rescans its dives', () async {
    expect(await openDetectors(), contains('transmitter_gear_serial_mismatch'));

    await h.run([
      updateOp('equipment', 'tx', {'serial_number': '555'}),
    ]);
    await QualityScanScheduler.instance.idle;

    expect(
      await openDetectors(),
      isNot(contains('transmitter_gear_serial_mismatch')),
    );
  });
}
