import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
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

/// The gear-serial mismatch finding (issue #3367) reads the registry entry
/// and its linked gear item, not the dive, so every change to either queues
/// a rescan of the dives the entry matches, or a stored finding outlives
/// the disagreement it reported.
void main() {
  late AppDatabase db;
  late TransmitterRepository repo;
  final now = DateTime.utc(2026, 9, 1);

  setUp(() async {
    db = await setUpTestDatabase();
    QualityScanScheduler.enabled = true;
    addTearDown(applyGlobalTestDefaults);
    repo = TransmitterRepository();

    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'diver-1',
            name: 'Alex',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'tx',
            name: 'Tx',
            type: 'transmitter',
            createdAt: 1,
            updatedAt: 1,
            diverId: const Value('diver-1'),
            serialNumber: const Value('999'),
          ),
        );
    final entry = DateTime.utc(2026, 7, 1, 10);
    await DiveRepository().createDive(
      domain.Dive(
        id: 'd1',
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 40),
        maxDepth: 30,
        diverId: 'diver-1',
        tanks: const [
          domain.DiveTank(
            id: 't1',
            gasMix: domain.GasMix(o2: 21, he: 0),
            transmitterSerial: '555',
          ),
        ],
      ),
    );
    await repo.create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '555',
        label: 'Main',
        transmitterEquipmentId: 'tx',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await QualityScanScheduler.instance.idle;
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> openDetectors() async => {
    for (final f in await QualityFindingsRepository().getFindings(
      diveId: 'd1',
      status: QualityStatus.open,
    ))
      f.detectorId,
  };

  test('creating the linked entry flags the mismatch', () async {
    expect(await openDetectors(), contains('transmitter_gear_serial_mismatch'));
  });

  test('correcting the gear serial retires the finding', () async {
    await (db.update(db.equipment)..where((t) => t.id.equals('tx'))).write(
      const EquipmentCompanion(serialNumber: Value('555')),
    );
    await repo.rescanDivesForTransmitterItem('tx');
    await QualityScanScheduler.instance.idle;

    expect(
      await openDetectors(),
      isNot(contains('transmitter_gear_serial_mismatch')),
    );
  });

  test('re-keying the entry rescans the dives of its old serial', () async {
    final entry = (await repo.getById('e1'))!;
    await repo.update(entry.copyWith(transmitterSerial: '777'));
    await QualityScanScheduler.instance.idle;

    final open = await openDetectors();
    expect(open, isNot(contains('transmitter_gear_serial_mismatch')));
    expect(open, contains('unknown_transmitter'));
  });

  test('deleting the entry rescans its dives', () async {
    await repo.delete('e1');
    await QualityScanScheduler.instance.idle;

    final open = await openDetectors();
    expect(open, isNot(contains('transmitter_gear_serial_mismatch')));
    expect(open, contains('unknown_transmitter'));
  });
}
