import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/services/shared_gear_notes.dart';

import '../../../../helpers/test_database.dart';

/// Which gear on the dive being edited is also on another profile's
/// overlapping dive (issue #2853).
void main() {
  late AppDatabase db;
  final ten = DateTime.utc(2026, 5, 1, 10);
  DateTime at(int minutes) => ten.add(Duration(minutes: minutes));

  Future<void> addDiver(String id, String name) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(id: id, name: name, createdAt: 1, updatedAt: 1),
      );

  Future<void> addDive(String id, String? diver, DateTime entry) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(diver),
          diveDateTime: entry.millisecondsSinceEpoch,
          createdAt: 1,
          updatedAt: 1,
          entryTime: Value(entry.millisecondsSinceEpoch),
          runtime: const Value(40 * 60),
        ),
      );

  Future<void> wear(String dive, String item) => db
      .into(db.diveEquipment)
      .insert(DiveEquipmentCompanion.insert(diveId: dive, equipmentId: item));

  Future<Map<String, SharedGearNote>> notes({
    String? diveId,
    DateTime? entry,
    DateTime? exit,
  }) => sharedGearNotesFor(
    db,
    diveId: diveId,
    diverId: 'bill',
    entry: entry ?? ten,
    exit: exit ?? at(40),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await addDiver('bill', 'Bill');
    await addDiver('anna', 'Anna');
    for (final id in ['light', 'mask']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'other',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    await addDive('a1', 'anna', at(10));
    await wear('a1', 'light');
  });

  tearDown(tearDownTestDatabase);

  test(
    'a new dive sees gear on an overlapping dive of another profile',
    () async {
      final n = await notes();
      expect(n.keys, ['light']);
      expect(n['light']!.diverName, 'Anna');
      expect(n['light']!.entry, at(10));
      expect(n['light']!.entry.isUtc, isTrue);
    },
  );

  test('the note follows the unsaved times', () async {
    expect(await notes(entry: at(120), exit: at(160)), isEmpty);
    expect(
      await notes(entry: at(45), exit: at(90)),
      isEmpty,
      reason: '5 min',
    );
    expect((await notes(entry: at(44), exit: at(90))).keys, ['light']);
  });

  test('same-profile and profile-less dives are ignored', () async {
    await addDive('b2', 'bill', at(5));
    await wear('b2', 'mask');
    await addDive('n1', null, at(5));
    await wear('n1', 'mask');
    expect((await notes()).keys, ['light']);
  });

  test('the dive itself never matches', () async {
    expect(await notes(diveId: 'a1'), isEmpty);
  });

  test('the earliest other dive wins', () async {
    await addDive('a2', 'anna', at(-10));
    await wear('a2', 'light');
    expect((await notes())['light']!.entry, at(-10));
  });
}
