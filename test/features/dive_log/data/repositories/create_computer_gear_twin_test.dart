import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide DiveComputer;
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

import '../../../../helpers/test_database.dart';

/// createComputer is the only repository path that genuinely inserts a registry
/// row, so it is where the gear twin is seeded. It marks the row pending ONCE,
/// after the optional equipment_id write, so the row carries a single HLC
/// representing its final state rather than two clock ticks for one creation.
void main() {
  late AppDatabase db;
  late DiveComputerRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repo = DiveComputerRepository();
  });
  tearDown(tearDownTestDatabase);

  DiveComputer computer({String id = 'c1'}) => DiveComputer(
    id: id,
    diverId: 'd1',
    name: 'My Perdix',
    manufacturer: 'Shearwater',
    model: 'Perdix 2',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Future<int> pendingCountForComputer(String id) async {
    final row = await db
        .customSelect(
          "SELECT COUNT(*) AS c FROM sync_records "
          "WHERE entity_type = 'diveComputers' AND record_id = ?",
          variables: [Variable<String>(id)],
        )
        .getSingle();
    return row.read<int>('c');
  }

  test('registering a computer seeds and stores its gear twin', () async {
    final created = await repo.createComputer(computer());

    final expected = diveComputerGearId('c1');
    expect(created.equipmentId, expected);

    final row = await db
        .customSelect("SELECT equipment_id FROM dive_computers WHERE id = 'c1'")
        .getSingle();
    expect(row.read<String?>('equipment_id'), expected);

    final gear = await db
        .customSelect(
          'SELECT type, name FROM equipment WHERE id = ?',
          variables: [Variable<String>(expected)],
        )
        .getSingle();
    expect(gear.read<String>('type'), 'computer');
    expect(gear.read<String>('name'), 'My Perdix');
  });

  test(
    'the registry row is still marked pending after the twin write',
    () async {
      // The pending mark moved to after the equipment_id update so the row gets
      // one HLC instead of two. It must remain unconditional: a computer is a
      // synced entity whether or not its twin resolved.
      await repo.createComputer(computer());

      expect(await pendingCountForComputer('c1'), 1);
    },
  );
}
