import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/marine_life/domain/species_revamp_ids.dart';

/// The per-diver species tables (issue #5027), each with its sync entity
/// type and the id derivation its rows are keyed by.
const speciesRevampTables =
    <
      ({
        String table,
        String entityType,
        String Function(String diverId, String speciesId) idOf,
      })
    >[
      (
        table: 'species_covers',
        entityType: 'speciesCovers',
        idOf: speciesCoverId,
      ),
      (
        table: 'species_practice',
        entityType: 'speciesPractice',
        idOf: speciesPracticeId,
      ),
    ];

/// Tombstones every cover and practice row of [speciesId] before the
/// species is deleted, so peers drop them with it rather than waiting on a
/// cascade of their own.
Future<void> tombstoneSpeciesRevampRows(
  AppDatabase db,
  SyncRepository sync,
  String speciesId,
) async {
  for (final spec in speciesRevampTables) {
    final rows = await db
        .customSelect(
          'SELECT id FROM ${spec.table} WHERE species_id = ?',
          variables: [Variable.withString(speciesId)],
        )
        .get();
    for (final row in rows) {
      await sync.logDeletion(
        entityType: spec.entityType,
        recordId: row.data['id'] as String,
      );
    }
    await db.customStatement('DELETE FROM ${spec.table} WHERE species_id = ?', [
      speciesId,
    ]);
  }
}

/// Moves every cover and practice row of [from] onto [to] under the id
/// derived for [to]. Unlike the species row, which the fold deletes without
/// publishing so a device still on the old catalog keeps it, these rows ARE
/// tombstoned: a peer on the old catalog loses its record for the retired
/// species and receives the moved one, held by FK repair until its own
/// upgrade adds the replacement. Accepted: practice and covers are small and
/// rebuild themselves. A diver who already has a row on [to] keeps it and the
/// moved one is dropped. Every row left behind is tombstoned and every row
/// written is marked pending.
Future<void> moveSpeciesRevampRows(
  AppDatabase db,
  SyncRepository sync, {
  required String from,
  required String to,
  required int now,
}) async {
  for (final spec in speciesRevampTables) {
    final rows = await db
        .customSelect(
          'SELECT id, diver_id FROM ${spec.table} WHERE species_id = ?',
          variables: [Variable.withString(from)],
        )
        .get();
    for (final row in rows) {
      final oldId = row.data['id'] as String;
      final diverId = row.data['diver_id'] as String;
      final newId = spec.idOf(diverId, to);
      if (!await _exists(db, spec.table, newId)) {
        await _copyRow(
          db,
          spec.table,
          oldId,
          set: 'id = ?, species_id = ?, updated_at = ?',
          values: [newId, to, now],
        );
        await sync.markRecordPending(
          entityType: spec.entityType,
          recordId: newId,
          localUpdatedAt: now,
        );
      }
      await db.customStatement('DELETE FROM ${spec.table} WHERE id = ?', [
        oldId,
      ]);
      await sync.logDeletion(entityType: spec.entityType, recordId: oldId);
    }
  }
}

/// Copies [from]'s rows of [table] (a [speciesRevampTables] table) onto [to]
/// under the id derived for [to], for every species [to] has no row for yet,
/// marked pending. A diver merge calls it before it deletes [from]'s rows, so
/// the duplicate's covers and practice survive where the keeper has none.
/// Returns the ids written, for undo.
Future<List<String>> copySpeciesRevampRowsToDiver(
  AppDatabase db,
  SyncRepository sync, {
  required String table,
  required String from,
  required String to,
  required int now,
}) async {
  final spec = speciesRevampTables.where((s) => s.table == table).firstOrNull;
  if (spec == null) return const [];
  final rows = await db
      .customSelect(
        'SELECT id, species_id FROM $table WHERE diver_id = ?',
        variables: [Variable.withString(from)],
      )
      .get();
  final created = <String>[];
  for (final row in rows) {
    final newId = spec.idOf(to, row.data['species_id'] as String);
    if (await _exists(db, table, newId)) continue;
    await _copyRow(
      db,
      table,
      row.data['id'] as String,
      set: 'id = ?, diver_id = ?, updated_at = ?',
      values: [newId, to, now],
    );
    await sync.markRecordPending(
      entityType: spec.entityType,
      recordId: newId,
      localUpdatedAt: now,
    );
    created.add(newId);
  }
  return created;
}

Future<bool> _exists(AppDatabase db, String table, String id) async =>
    await db
        .customSelect(
          'SELECT 1 FROM $table WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull() !=
    null;

/// Inserts a copy of [table]'s row [id] with [set] applied to the copy.
Future<void> _copyRow(
  AppDatabase db,
  String table,
  String id, {
  required String set,
  required List<Object?> values,
}) async {
  // Dropped first: a copy that failed halfway may have left one shaped like
  // the other table.
  await db.customStatement('DROP TABLE IF EXISTS _revamp_move');
  await db.customStatement(
    'CREATE TEMP TABLE _revamp_move AS SELECT * FROM $table WHERE 0',
  );
  await db.customStatement('DELETE FROM _revamp_move');
  await db.customStatement(
    'INSERT INTO _revamp_move SELECT * FROM $table WHERE id = ?',
    [id],
  );
  await db.customStatement('UPDATE _revamp_move SET $set', values);
  await db.customStatement('INSERT INTO $table SELECT * FROM _revamp_move');
  await db.customStatement('DROP TABLE _revamp_move');
}
