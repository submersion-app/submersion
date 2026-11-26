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
/// derived for [to]. A diver who already has a row on [to] keeps it and the
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
      final taken = await db
          .customSelect(
            'SELECT 1 FROM ${spec.table} WHERE id = ?',
            variables: [Variable.withString(newId)],
          )
          .getSingleOrNull();
      if (taken == null) {
        // Copy every column, then re-key it onto the kept species.
        await db.customStatement(
          'CREATE TEMP TABLE IF NOT EXISTS _revamp_move AS '
          'SELECT * FROM ${spec.table} WHERE 0',
        );
        await db.customStatement('DELETE FROM _revamp_move');
        await db.customStatement(
          'INSERT INTO _revamp_move SELECT * FROM ${spec.table} WHERE id = ?',
          [oldId],
        );
        await db.customStatement(
          'UPDATE _revamp_move SET id = ?, species_id = ?, updated_at = ?',
          [newId, to, now],
        );
        await db.customStatement(
          'INSERT INTO ${spec.table} SELECT * FROM _revamp_move',
        );
        await db.customStatement('DROP TABLE _revamp_move');
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
