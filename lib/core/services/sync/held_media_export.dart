/// Holding media kept with no place back from older devices (issue #5122).
///
/// A build before [heldMediaSchemaVersion] deletes a media row
/// with no dive, site or gear (its orphan sweep, and its dive and site
/// delete cascades) and syncs the delete back. While such a device is in
/// the library, those rows and their children are left out of every export;
/// [HeldMediaStore] remembers which, so the release can stamp them again.
library;

import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/held_media_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart'
    show SyncData;
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';

/// The first schema whose builds keep media with no dive, site or gear:
/// their orphan sweep and delete cascades spare a row with
/// `retain_in_library` set. A device that publishes an older
/// `writerSchemaVersion` would delete such a row and sync the delete.
const int heldMediaSchemaVersion = 394;

/// The sync entities that belong to one media row, keyed by `mediaId`. Held
/// with their row: a build before v1.8.5 drops a child whose row is missing,
/// and never takes it back once the row arrives.
const Set<String> heldMediaChildEntities = {
  'mediaEnrichment',
  'mediaTags',
  'mediaSpecies',
  'mediaPeople',
  'mediaIdentificationRuns',
  'mediaIdentifications',
  'mediaIdentificationCrops',
};

/// Whether a device that published [manifest] would delete media kept with
/// no place.
bool isOlderThanHeldMedia(SyncManifest manifest) =>
    (manifest.writerSchemaVersion ?? manifest.schemaVersion ?? 0) <
    heldMediaSchemaVersion;

/// Whether any of [peers] other than [fencedPeerIds] would delete media kept
/// with no place.
bool olderPeersPresent(
  Iterable<SyncManifest> peers,
  Set<String> fencedPeerIds,
) => peers.any(
  (m) => !fencedPeerIds.contains(m.deviceId) && isOlderThanHeldMedia(m),
);

/// The media rows an export must leave out: none unless [holding]. When
/// holding, every row kept with no dive, site or gear, each recorded in
/// [HeldMediaStore] so the release finds it.
Future<Set<String>> heldMediaIdsForExport(
  AppDatabase db, {
  required bool holding,
  DateTime Function() now = DateTime.now,
}) async {
  if (!holding) return const {};
  final m = db.media;
  final rows =
      await (db.selectOnly(m)
            ..addColumns([m.id])
            ..where(
              m.retainInLibrary.equals(true) &
                  m.diveId.isNull() &
                  m.siteId.isNull() &
                  m.equipmentId.isNull(),
            ))
          .get();
  final ids = {for (final row in rows) row.read(m.id)!};
  await HeldMediaStore(database: db).hold(ids, at: now());
  return ids;
}

/// Whether [row] of [entityKey] belongs to a media row in [held].
bool isHeldMediaRow(
  String entityKey,
  Map<String, dynamic> row,
  Set<String> held,
) {
  if (held.isEmpty) return false;
  if (entityKey == 'media') return held.contains(row['id']);
  if (heldMediaChildEntities.contains(entityKey)) {
    return held.contains(row['mediaId']);
  }
  return false;
}

/// [data] without the rows of the media in [held] and their children.
SyncData withoutHeldMedia(SyncData data, Set<String> held) {
  if (held.isEmpty) return data;
  final json = data.toJson();
  var changed = false;
  final kept = <String, dynamic>{};
  for (final entry in json.entries) {
    final rows = entry.value;
    if (rows is! List) {
      kept[entry.key] = rows;
      continue;
    }
    final remaining = [
      for (final row in rows)
        if (row is! Map<String, dynamic> ||
            !isHeldMediaRow(entry.key, row, held))
          row,
    ];
    if (remaining.length != rows.length) changed = true;
    kept[entry.key] = remaining;
  }
  return changed ? SyncData.fromJson(kept) : data;
}
