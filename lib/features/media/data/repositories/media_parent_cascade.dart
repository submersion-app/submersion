import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;

/// The parents a deletion is about to remove, keyed by the media column
/// that references each kind.
///
/// A deletion that takes several kinds at once (a diver takes their dives,
/// private sites, gear and buddies) must classify each media row against all
/// of them together. The single-entity partitions cannot be chained: the
/// dive partition keeps a photo its site still links, the site partition
/// keeps a photo its dive still links, and a photo on both would outlive a
/// deletion that removes both.
class DyingMediaParents {
  const DyingMediaParents({
    this.diveIds = const {},
    this.siteIds = const {},
    this.equipmentIds = const {},
    this.buddyIds = const {},
  });

  final Set<String> diveIds;
  final Set<String> siteIds;
  final Set<String> equipmentIds;

  /// Buddies whose signatures would lose their signer. A signer is not a
  /// logbook link, so it never keeps a row alive or dooms one.
  final Set<String> buddyIds;

  bool get isEmpty =>
      diveIds.isEmpty &&
      siteIds.isEmpty &&
      equipmentIds.isEmpty &&
      buddyIds.isEmpty;
}

/// A media row that outlives the deletion. Each field names the dying parent
/// the row linked through that column, or is null where the link was not
/// dying (absent, or a surviving parent).
class MediaSurvivor {
  const MediaSurvivor(
    this.id, {
    this.diveId,
    this.siteId,
    this.equipmentId,
    this.signerId,
  });

  final String id;
  final String? diveId;
  final String? siteId;
  final String? equipmentId;
  final String? signerId;
}

/// What a deletion does to its parents' media, read before it runs.
class MediaCascadePlan {
  const MediaCascadePlan({
    this.doomed = const [],
    this.survivors = const [],
    this.enrichmentIds = const [],
  });

  static const empty = MediaCascadePlan();

  /// Rows whose every logbook link is dying. Full items, because the
  /// blob-delete intent needs the content hash, filename and type.
  final List<domain.MediaItem> doomed;

  /// Rows a surviving parent still links, or reached only through a dying
  /// signer.
  final List<MediaSurvivor> survivors;

  /// Enrichment rows of the dying dives. Their foreign key cascades, so the
  /// dive deletes remove them with no tombstone; the caller logs these.
  final List<String> enrichmentIds;
}

/// Reads what a deletion of [parents] does to media. Call it before the
/// deletion: afterwards ON DELETE SET NULL has already cleared the links
/// this classifies by.
///
/// A row is doomed when it has at least one logbook link (dive, site or
/// equipment) and every one of them is dying: the same "linked to the
/// logbook" definition as `MediaRepository.isLinkedToLogbook`. Anything else
/// the query reaches survives, with its dying links named.
Future<MediaCascadePlan> planMediaCascade(
  AppDatabase db,
  DyingMediaParents parents,
) async {
  if (parents.isEmpty) return MediaCascadePlan.empty;

  final rows =
      await (db.select(db.media)..where((m) {
            final reaches = <Expression<bool>>[
              if (parents.diveIds.isNotEmpty) m.diveId.isIn(parents.diveIds),
              if (parents.siteIds.isNotEmpty) m.siteId.isIn(parents.siteIds),
              if (parents.equipmentIds.isNotEmpty)
                m.equipmentId.isIn(parents.equipmentIds),
              if (parents.buddyIds.isNotEmpty)
                m.signerId.isIn(parents.buddyIds),
            ];
            return reaches.reduce((a, b) => a | b);
          }))
          .get();

  String? dyingOf(String? link, Set<String> dying) =>
      link != null && dying.contains(link) ? link : null;

  final doomed = <domain.MediaItem>[];
  final survivors = <MediaSurvivor>[];
  for (final row in rows) {
    final dive = dyingOf(row.diveId, parents.diveIds);
    final site = dyingOf(row.siteId, parents.siteIds);
    final gear = dyingOf(row.equipmentId, parents.equipmentIds);
    final linked =
        row.diveId != null || row.siteId != null || row.equipmentId != null;
    final kept =
        (row.diveId != null && dive == null) ||
        (row.siteId != null && site == null) ||
        (row.equipmentId != null && gear == null);
    if (linked && !kept) {
      doomed.add(mediaItemFromRow(row));
    } else {
      survivors.add(
        MediaSurvivor(
          row.id,
          diveId: dive,
          siteId: site,
          equipmentId: gear,
          signerId: dyingOf(row.signerId, parents.buddyIds),
        ),
      );
    }
  }

  final enrichmentIds = parents.diveIds.isEmpty
      ? const <String>[]
      : [
          for (final e in await (db.select(
            db.mediaEnrichment,
          )..where((t) => t.diveId.isIn(parents.diveIds))).get())
            e.id,
        ];

  return MediaCascadePlan(
    doomed: doomed,
    survivors: survivors,
    enrichmentIds: enrichmentIds,
  );
}

/// Clears each survivor's links to the parents a deletion removed, stamps
/// the row and marks it pending, so peers take the unlink rather than each
/// nulling the link silently on its own schedule (issue #1954).
///
/// Runs after the deletion commits, when ON DELETE SET NULL has already
/// cleared those links locally with no stamp. So the write cannot be scoped
/// on the link still naming the parent. `NULLIF(column, dying)` clears a
/// link only while it still names the parent the plan saw dying (or is
/// already null): a row relinked since the plan keeps its new link. A null
/// argument leaves the column unchanged, because `x = NULL` is never true.
///
/// Sends no local-change notice: the caller announces the whole deletion.
Future<void> unlinkMediaFromDeletedParents(
  AppDatabase db,
  SyncRepository sync,
  List<MediaSurvivor> survivors,
) async {
  if (survivors.isEmpty) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.transaction(() async {
    for (final s in survivors) {
      final written = await db.customUpdate(
        'UPDATE media SET '
        'dive_id = NULLIF(dive_id, ?), '
        'site_id = NULLIF(site_id, ?), '
        'equipment_id = NULLIF(equipment_id, ?), '
        'signer_id = NULLIF(signer_id, ?), '
        'updated_at = ? '
        'WHERE id = ?',
        variables: [
          Variable<String>(s.diveId),
          Variable<String>(s.siteId),
          Variable<String>(s.equipmentId),
          Variable<String>(s.signerId),
          Variable<int>(now),
          Variable<String>(s.id),
        ],
        updates: {db.media},
        updateKind: UpdateKind.update,
      );
      // Deleted since the plan: nothing survived to publish.
      if (written == 0) continue;
      await sync.markRecordPending(
        entityType: 'media',
        recordId: s.id,
        localUpdatedAt: now,
      );
    }
  });
}
