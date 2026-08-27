import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Adopting a replaced library replays the epoch's full base + changeset
/// history through `upsertRecords` (#858). Records exported before a schema
/// change lack the newer columns entirely, and Drift's generated `fromJson`
/// does a straight cast per column -- a missing non-nullable bool crashes with
/// "type 'Null' is not a subtype of type 'bool' in type cast", permanently
/// blocking adoption. Replay must instead hydrate missing non-nullable columns
/// with their schema defaults, for every synced entity -- not just the ones
/// with hand-maintained fallback maps (diverSettings).
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// Exports [id] of [entityType] in wire format, then strips [keys] to
  /// simulate a changeset written by an app version predating those columns.
  Future<Map<String, dynamic>> legacyRecord(
    String entityType,
    String id,
    List<String> keys,
  ) async {
    final exported = await serializer.fetchRecord(entityType, id);
    expect(exported, isNotNull);
    final legacy = Map<String, dynamic>.from(exported!);
    for (final key in keys) {
      legacy.remove(key);
    }
    return legacy;
  }

  test('batched replay hydrates missing non-nullable bools on dives', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    final legacy = await legacyRecord('dives', 'dive-1', [
      'isFavorite',
      'isPlanned',
    ]);
    await (db.delete(db.dives)..where((t) => t.id.equals('dive-1'))).go();

    // The adopt path (#858): must not throw on the missing bool columns.
    await serializer.upsertRecords('dives', [legacy]);

    final row = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('dive-1'))).getSingle();
    expect(row.isFavorite, isFalse);
    expect(row.isPlanned, isFalse);
  });

  test('replay hydrates a default-true bool with true, not false', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'eq-1',
            name: 'AL80',
            type: 'tank',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final legacy = await legacyRecord('equipment', 'eq-1', ['isActive']);
    await (db.delete(db.equipment)..where((t) => t.id.equals('eq-1'))).go();

    await serializer.upsertRecords('equipment', [legacy]);

    final row = await (db.select(
      db.equipment,
    )..where((t) => t.id.equals('eq-1'))).getSingle();
    // The schema default is TRUE; a blanket null->false fill would silently
    // deactivate every piece of equipment in the replayed history.
    expect(row.isActive, isTrue);
  });

  test('replay treats an explicit null like a missing key', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-2',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    final legacy = await legacyRecord('dives', 'dive-2', []);
    legacy['isFavorite'] = null;
    await (db.delete(db.dives)..where((t) => t.id.equals('dive-2'))).go();

    await serializer.upsertRecords('dives', [legacy]);

    final row = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('dive-2'))).getSingle();
    expect(row.isFavorite, isFalse);
  });

  test('replay preserves non-default values that are present', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-3',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    final legacy = await legacyRecord('dives', 'dive-3', []);
    legacy['isFavorite'] = true;
    await (db.delete(db.dives)..where((t) => t.id.equals('dive-3'))).go();

    await serializer.upsertRecords('dives', [legacy]);

    final row = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('dive-3'))).getSingle();
    expect(row.isFavorite, isTrue);
  });

  test('unknown entity types stay a silent no-op', () async {
    // A payload from a newer app version can carry entity types this build
    // has never heard of; upsertRecord ignores them, and the schema-default
    // hydration must not turn that into a throw.
    await serializer.upsertRecord('entityFromTheFuture', {
      'id': 'x1',
      'someKey': true,
    });
  });

  test(
    'single-record replay hydrates missing non-nullable bools too',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'dive-4',
              diveDateTime: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      final legacy = await legacyRecord('dives', 'dive-4', ['isFavorite']);
      await (db.delete(db.dives)..where((t) => t.id.equals('dive-4'))).go();

      // The conflict-resolution / incremental path shares the same hydration.
      await serializer.upsertRecord('dives', legacy);

      final row = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('dive-4'))).getSingle();
      expect(row.isFavorite, isFalse);
    },
  );
}
