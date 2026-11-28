import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/held_media_store.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';

/// Sends media this device held back once it is safe to (issue #5122).
///
/// Exports go by clock watermark, so a row left out of one export is never
/// picked up by the next on its own: its clock is already below the
/// watermark. Releasing stamps the row, its fact clocks and every child row
/// again, above any watermark, so the next export carries them all. Run it
/// before the export it is meant for.
class HeldMediaReleaser {
  HeldMediaReleaser({
    required AppDatabase db,
    required SyncRepository sync,
    HeldMediaStore? held,
    DateTime Function() now = DateTime.now,
  }) : _db = db,
       _sync = sync,
       _held = held ?? HeldMediaStore(database: db),
       _now = now;

  final AppDatabase _db;
  final SyncRepository _sync;
  final HeldMediaStore _held;
  final DateTime Function() _now;

  /// Releases every held row that may go out: all of them when not
  /// [holding], else those that gained a dive, site or gear. A held row
  /// that is gone is forgotten. Returns how many were released.
  Future<int> release({required bool holding}) async {
    final ids = await _held.heldIds();
    if (ids.isEmpty) return 0;
    final m = _db.media;
    final rows = await (_db.select(m)..where((t) => t.id.isIn(ids))).get();
    final present = {for (final row in rows) row.id};
    await _held.release(ids.difference(present));

    final ready = [
      for (final row in rows)
        if (!holding ||
            row.diveId != null ||
            row.siteId != null ||
            row.equipmentId != null)
          row.id,
    ];
    final at = _now().millisecondsSinceEpoch;
    for (final id in ready) {
      await _sync.markRecordPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: at,
        alsoStamp: SyncFactGroups.of('media'),
      );
      for (final (entityType, childIds) in await _childrenOf(id)) {
        for (final childId in childIds) {
          await _sync.markRecordPending(
            entityType: entityType,
            recordId: childId,
            localUpdatedAt: at,
          );
        }
      }
      await _held.release([id]);
    }
    return ready.length;
  }

  /// Each child entity of media [mediaId] with the record ids it holds, by
  /// the key `markRecordPending` stamps (a run's key is its media id).
  Future<List<(String, List<String>)>> _childrenOf(String mediaId) async {
    Future<List<String>> ids(String table, String key) async {
      final rows = await _db
          .customSelect(
            'SELECT $key AS k FROM $table WHERE media_id = ?',
            variables: [Variable.withString(mediaId)],
          )
          .get();
      return [for (final row in rows) row.read<String>('k')];
    }

    return [
      ('mediaEnrichment', await ids('media_enrichment', 'id')),
      ('mediaTags', await ids('media_tags', 'id')),
      ('mediaSpecies', await ids('media_species', 'id')),
      ('mediaPeople', await ids('media_people', 'id')),
      (
        'mediaIdentificationRuns',
        await ids('media_identification_runs', 'media_id'),
      ),
      ('mediaIdentifications', await ids('media_identifications', 'id')),
      (
        'mediaIdentificationCrops',
        await ids('media_identification_crops', 'id'),
      ),
    ];
  }
}
