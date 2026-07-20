import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Per-record sync coverage for the four pre-dive checklist entities:
///   preDiveChecklistTemplates, preDiveChecklistTemplateItems,
///   preDiveSessions, preDiveSessionItems.
///
/// The suite-wide fetchRecord / upsert / delete tests enumerate a curated list
/// of entity types that omits these four, so their per-type switch branches
/// (fetchRecord, fetchRecords, upsertRecord, upsertRecords, recordIdsFor,
/// deleteRecord, deleteAllRecords / _syncTableFor) were never exercised.
///
/// Each type is driven through a real in-memory database round-trip: a minimal
/// row is seeded via raw SQL, read back through `fetchRecord` (yielding exactly
/// the `row.toJson()` map the write side consumes), then pushed through both
/// upsert entry points and finally deleted. FK enforcement is disabled so a
/// throwaway placeholder row need not satisfy its parent references.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  // The four pre-dive entity types paired with their live SQL table names.
  late List<({String type, String table})> targets;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    targets = <({String type, String table})>[
      (
        type: 'preDiveChecklistTemplates',
        table: db.preDiveChecklistTemplates.actualTableName,
      ),
      (
        type: 'preDiveChecklistTemplateItems',
        table: db.preDiveChecklistTemplateItems.actualTableName,
      ),
      (type: 'preDiveSessions', table: db.preDiveSessions.actualTableName),
      (
        type: 'preDiveSessionItems',
        table: db.preDiveSessionItems.actualTableName,
      ),
    ];
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// Inserts one minimal row into [table]: the single-column primary key is set
  /// to [id]; every other NOT NULL column with no default gets a
  /// type-appropriate placeholder.
  Future<void> seedMinimalRow(String table, String id) async {
    final cols = await db
        .customSelect(
          'SELECT * FROM pragma_table_info(?)',
          variables: [Variable.withString(table)],
        )
        .get();
    final pkCols = cols.where((c) => (c.data['pk'] as int? ?? 0) > 0).toList();
    if (pkCols.length != 1) {
      throw StateError('table $table does not have a single-column PK');
    }
    final pkName = pkCols.first.read<String>('name');

    final names = <String>[];
    final placeholders = <String>[];
    final values = <Object?>[];
    for (final c in cols) {
      final name = c.read<String>('name');
      final notNull = (c.data['notnull'] as int? ?? 0) == 1;
      final hasDefault = c.data['dflt_value'] != null;
      final type = (c.data['type'] as String? ?? '').toUpperCase();
      if (name == pkName) {
        names.add('"$name"');
        placeholders.add('?');
        values.add(id);
      } else if (notNull && !hasDefault) {
        names.add('"$name"');
        placeholders.add('?');
        if (type.contains('INT')) {
          values.add(0);
        } else if (type.contains('REAL') ||
            type.contains('FLOA') ||
            type.contains('DOUB')) {
          values.add(0.0);
        } else if (type.contains('BLOB')) {
          values.add(Uint8List(0));
        } else {
          values.add('x');
        }
      }
    }
    await db.customStatement(
      'INSERT INTO "$table" (${names.join(",")}) VALUES (${placeholders.join(",")})',
      values,
    );
  }

  group('SyncDataSerializer pre-dive per-record path', () {
    test('fetchRecord returns null for an absent row of each pre-dive '
        'type', () async {
      for (final t in targets) {
        expect(
          await serializer.fetchRecord(t.type, 'no-such-id'),
          isNull,
          reason: '${t.type} must return null when the row is absent',
        );
      }
    });

    test('seed -> fetchRecord -> upsertRecord + upsertRecords -> fetchRecords '
        'round-trips every pre-dive type', () async {
      // Placeholder rows carry unsatisfiable FK values; disable enforcement so
      // this exercises the row mapping + fromJson switch, not referential
      // integrity.
      await db.customStatement('PRAGMA foreign_keys = OFF');

      final failures = <String>[];
      for (final t in targets) {
        final id = 'seed-${t.type}';
        try {
          await seedMinimalRow(t.table, id);

          // fetchRecord: the single-row read side (row?.toJson()).
          final row = await serializer.fetchRecord(t.type, id);
          expect(row, isNotNull, reason: '${t.type} seeded row must fetch');
          expect(row!['id'], id);

          // Both write entry points consume the fetched JSON via fromJson:
          //   upsertRecord   -> single import/adopt path
          //   upsertRecords  -> batched merge path
          await serializer.upsertRecord(t.type, row);
          await serializer.upsertRecords(t.type, [row]);
          expect(
            await serializer.fetchRecord(t.type, id),
            isNotNull,
            reason: '${t.type} must survive an upsert round-trip',
          );

          // fetchRecords: the batched read side keyed by an id list.
          final byId = await serializer.fetchRecords(t.type, [id, 'missing']);
          expect(byId.keys, contains(id));
          expect(byId.keys, isNot(contains('missing')));
          expect(byId[id]!['id'], id);
        } catch (e) {
          failures.add('${t.type}: $e');
        }
      }

      expect(
        failures,
        isEmpty,
        reason: 'every pre-dive type must round-trip cleanly',
      );
    });

    test(
      'recordIdsFor enumerates seeded ids for every pre-dive type',
      () async {
        await db.customStatement('PRAGMA foreign_keys = OFF');

        for (final t in targets) {
          final id = 'ids-${t.type}';
          await seedMinimalRow(t.table, id);
          final ids = await serializer.recordIdsFor(t.type);
          expect(
            ids,
            contains(id),
            reason: 'recordIdsFor(${t.type}) must include the seeded id',
          );
        }
      },
    );

    test('deleteRecord removes a seeded row of each pre-dive type', () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');

      for (final t in targets) {
        final id = 'del-${t.type}';
        await seedMinimalRow(t.table, id);
        expect(await serializer.fetchRecord(t.type, id), isNotNull);

        await serializer.deleteRecord(t.type, id);
        expect(
          await serializer.fetchRecord(t.type, id),
          isNull,
          reason: 'deleteRecord(${t.type}) must remove the row',
        );
      }
    });

    test('deleteAllRecords clears user rows for every pre-dive type', () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');

      for (final t in targets) {
        final id = 'all-${t.type}';
        await seedMinimalRow(t.table, id);
      }

      // Sessions / session items fall through to _syncTableFor(entityType);
      // templates / template items take dedicated built-in-preserving branches.
      for (final t in targets) {
        await serializer.deleteAllRecords(t.type);
        expect(
          await serializer.fetchRecord(t.type, 'all-${t.type}'),
          isNull,
          reason: 'deleteAllRecords(${t.type}) must clear the seeded user row',
        );
      }
    });
  });
}
