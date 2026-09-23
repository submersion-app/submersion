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

/// Ids per statement. The bundled SQLite binds at most 32766 variables, and
/// a diver's whole library can pass that in one list; 900 is the bound the
/// rest of the codebase already chunks by. Public so a caller handing the
/// doomed rows onward can bound those calls too.
const mediaCascadeIdChunk = 900;

Iterable<List<T>> _chunks<T>(List<T> items) sync* {
  for (var i = 0; i < items.length; i += mediaCascadeIdChunk) {
    yield items.sublist(
      i,
      i + mediaCascadeIdChunk < items.length
          ? i + mediaCascadeIdChunk
          : items.length,
    );
  }
}

/// What a deletion does to its parents' media, read before it runs.
class MediaCascadePlan {
  const MediaCascadePlan({
    this.parents = const DyingMediaParents(),
    this.doomed = const [],
    this.survivors = const [],
    this.enrichmentIds = const [],
  });

  static const empty = MediaCascadePlan();

  /// The dying parents this plan was read against, kept so the doomed set
  /// can be checked again right before it is deleted ([recheckDoomed]).
  final DyingMediaParents parents;

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

String? _dyingOf(String? link, Set<String> dying) =>
    link != null && dying.contains(link) ? link : null;

/// Whether some logbook link on [row] names a parent that is not dying.
/// That link alone keeps the row, whatever else dies around it.
///
/// Public so a caller can hand it to `MediaDeletionCoordinator` as `keepIf`,
/// where it is judged inside the delete's own transaction.
bool mediaRowLivesOn(MediaData row, DyingMediaParents parents) =>
    (row.diveId != null && !parents.diveIds.contains(row.diveId)) ||
    (row.siteId != null && !parents.siteIds.contains(row.siteId)) ||
    (row.equipmentId != null &&
        !parents.equipmentIds.contains(row.equipmentId));

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

  // One read per column and chunk, merged by id: a row reached through two
  // dying parents must be classified once.
  final byId = <String, MediaData>{};
  Future<void> reach(
    Set<String> ids,
    Expression<bool> Function($MediaTable m, List<String> chunk) where,
  ) async {
    for (final chunk in _chunks(ids.toList())) {
      for (final row in await (db.select(
        db.media,
      )..where((m) => where(m, chunk))).get()) {
        byId[row.id] = row;
      }
    }
  }

  await reach(parents.diveIds, (m, c) => m.diveId.isIn(c));
  await reach(parents.siteIds, (m, c) => m.siteId.isIn(c));
  await reach(parents.equipmentIds, (m, c) => m.equipmentId.isIn(c));
  await reach(parents.buddyIds, (m, c) => m.signerId.isIn(c));

  final doomed = <domain.MediaItem>[];
  final survivors = <MediaSurvivor>[];
  for (final row in byId.values) {
    final linked =
        row.diveId != null || row.siteId != null || row.equipmentId != null;
    if (linked && !mediaRowLivesOn(row, parents)) {
      doomed.add(mediaItemFromRow(row));
    } else {
      survivors.add(
        MediaSurvivor(
          row.id,
          diveId: _dyingOf(row.diveId, parents.diveIds),
          siteId: _dyingOf(row.siteId, parents.siteIds),
          equipmentId: _dyingOf(row.equipmentId, parents.equipmentIds),
          signerId: _dyingOf(row.signerId, parents.buddyIds),
        ),
      );
    }
  }

  final enrichmentIds = <String>{};
  for (final chunk in _chunks(parents.diveIds.toList())) {
    for (final e in await (db.select(
      db.mediaEnrichment,
    )..where((t) => t.diveId.isIn(chunk))).get()) {
      enrichmentIds.add(e.id);
    }
  }

  return MediaCascadePlan(
    parents: parents,
    doomed: doomed,
    survivors: survivors,
    enrichmentIds: enrichmentIds.toList(),
  );
}

/// The planned doomed rows that are still doomed now, read fresh.
///
/// The plan is applied after the deletion commits, and a row can be
/// relinked to a surviving parent in between (a sync pull, say). A row is
/// kept here while some logbook link names a live parent: links the
/// deletion's SET NULL cleared, and links still naming a dying parent, both
/// leave it doomed. A row already gone is dropped. The items are the fresh
/// reads, so a blob-delete intent is built from the row as it is now.
///
/// A pre-filter, not the guard: the delete that follows awaits a queue write
/// before it runs, and a relink can land in that gap too. The guard is
/// [mediaRowLivesOn] passed to the delete as `keepIf`, which judges each row
/// inside the delete's own transaction. This only spares the rows already
/// relinked the cost of a blob intent.
Future<List<domain.MediaItem>> recheckDoomed(
  AppDatabase db,
  MediaCascadePlan plan,
) async {
  final still = <domain.MediaItem>[];
  for (final chunk in _chunks([for (final m in plan.doomed) m.id])) {
    for (final row in await (db.select(
      db.media,
    )..where((m) => m.id.isIn(chunk))).get()) {
      if (!mediaRowLivesOn(row, plan.parents)) {
        still.add(mediaItemFromRow(row));
      }
    }
  }
  return still;
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
///
/// One transaction per survivor, so a row's unlink and its pending mark land
/// together or not at all, and one row that cannot be written does not roll
/// the others back: each survivor's unlink is the only thing that publishes
/// it. A failure is rethrown after the rest have been tried, so the caller
/// still hears about it. A survivor left unpublished this way is not lost:
/// its dying link is gone locally, and every peer clears the same link
/// itself when it applies the parent's tombstone.
Future<void> unlinkMediaFromDeletedParents(
  AppDatabase db,
  SyncRepository sync,
  List<MediaSurvivor> survivors,
) async {
  if (survivors.isEmpty) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  Object? firstError;
  StackTrace? firstStack;
  var failed = 0;
  for (final s in survivors) {
    try {
      await db.transaction(() async {
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
        if (written == 0) return;
        await sync.markRecordPending(
          entityType: 'media',
          recordId: s.id,
          localUpdatedAt: now,
        );
      });
    } on Object catch (e, stackTrace) {
      failed++;
      firstError ??= e;
      firstStack ??= stackTrace;
    }
  }
  if (firstError != null) {
    Error.throwWithStackTrace(
      StateError(
        '$failed of ${survivors.length} surviving media rows could not be '
        'unlinked: $firstError',
      ),
      firstStack!,
    );
  }
}
