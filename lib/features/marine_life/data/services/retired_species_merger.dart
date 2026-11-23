import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';

/// Folds each retired built-in species into the row that replaces it
/// (issue #4966): sightings, photo tags, expected species and the marine
/// life model's decided or named species move to the replacement, then the
/// retired row goes.
///
/// A dive keeps every sighting it had, so a dive logged against both twins
/// keeps two. A photo or site already tagged with the replacement drops its
/// retired tag instead, since a second tag of the same animal says nothing.
/// Every row it moves or drops is published, so the change reaches the
/// diver's other devices even before they upgrade.
class RetiredSpeciesMerger {
  RetiredSpeciesMerger(this._db, this._sync);

  final AppDatabase _db;
  final SyncRepository _sync;

  /// Merges every entry of [retired] (retired id to replacement id). With
  /// [keepEdited] a retired row the diver edited is left alone, references
  /// and all: the catalog upgrade never overwrites an edit. Returns whether
  /// anything changed.
  Future<bool> merge(
    Map<String, String> retired, {
    required bool keepEdited,
  }) async {
    var changed = false;
    for (final entry in retired.entries) {
      if (await _mergeOne(entry.key, entry.value, keepEdited: keepEdited)) {
        changed = true;
      }
    }
    return changed;
  }

  Future<bool> _mergeOne(
    String from,
    String to, {
    required bool keepEdited,
  }) async {
    final retiredRow = await _db
        .customSelect(
          'SELECT hlc FROM species WHERE id = ? AND is_built_in = 1',
          variables: [Variable.withString(from)],
        )
        .getSingleOrNull();
    if (retiredRow == null) return false;
    if (keepEdited && retiredRow.data['hlc'] != null) return false;
    final replacement = await _db
        .customSelect(
          'SELECT 1 FROM species WHERE id = ?',
          variables: [Variable.withString(to)],
        )
        .getSingleOrNull();
    if (replacement == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _moveSightings(from, to, now);
      await _moveTags(
        'media_species',
        'mediaSpecies',
        'media_id',
        from,
        to,
        now,
      );
      await _moveTags('site_species', 'siteSpecies', 'site_id', from, to, now);
      await _moveIdentifications(from, to, now);
      // Nothing points at the row now, so no cascade takes diver data. No
      // deletion is published: every device retires it at its own upgrade,
      // and one still on the old catalog must keep it for its own sightings.
      await _db.customStatement('DELETE FROM species WHERE id = ?', [from]);
      await _db.customStatement(
        "DELETE FROM sync_records WHERE entity_type = 'species' "
        'AND record_id = ?',
        [from],
      );
    });
    return true;
  }

  Future<List<String>> _ids(String sql, List<String> args) async {
    final rows = await _db
        .customSelect(sql, variables: [for (final a in args) Variable(a)])
        .get();
    return [for (final row in rows) row.data['id'] as String];
  }

  Future<void> _moveSightings(String from, String to, int now) async {
    final ids = await _ids('SELECT id FROM sightings WHERE species_id = ?', [
      from,
    ]);
    for (final id in ids) {
      await _db.customStatement(
        'UPDATE sightings SET species_id = ? WHERE id = ?',
        [to, id],
      );
      await _sync.markRecordPending(
        entityType: 'sightings',
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }

  /// Moves the [table] rows naming [from] to [to], or drops one whose
  /// [owner] (the photo or the site) already names [to].
  Future<void> _moveTags(
    String table,
    String entityType,
    String owner,
    String from,
    String to,
    int now,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT id, $owner AS owner FROM $table WHERE species_id = ?',
          variables: [Variable.withString(from)],
        )
        .get();
    for (final row in rows) {
      final id = row.data['id'] as String;
      final ownerId = row.data['owner'] as String;
      final twin = await _db
          .customSelect(
            'SELECT 1 FROM $table WHERE $owner = ? AND species_id = ? LIMIT 1',
            variables: [Variable.withString(ownerId), Variable.withString(to)],
          )
          .getSingleOrNull();
      if (twin != null) {
        await _db.customStatement('DELETE FROM $table WHERE id = ?', [id]);
        await _sync.logDeletion(entityType: entityType, recordId: id);
      } else {
        await _db.customStatement(
          'UPDATE $table SET species_id = ? WHERE id = ?',
          [to, id],
        );
        await _sync.markRecordPending(
          entityType: entityType,
          recordId: id,
          localUpdatedAt: now,
        );
      }
    }
  }

  /// The decided and the named (claimed) species are the diver's decision,
  /// so the move stamps the decision clock, as a decision made here does.
  Future<void> _moveIdentifications(String from, String to, int now) async {
    final ids = <String>{};
    for (final column in ['decided_species_id', 'claimed_species_id']) {
      ids.addAll(
        await _ids('SELECT id FROM media_identifications WHERE $column = ?', [
          from,
        ]),
      );
      await _db.customStatement(
        'UPDATE media_identifications SET $column = ? WHERE $column = ?',
        [to, from],
      );
    }
    for (final id in ids) {
      await _sync.markFactsPending(
        entityType: 'mediaIdentifications',
        recordId: id,
        localUpdatedAt: now,
        group: SyncFactGroups.identificationDecision,
      );
    }
  }
}
