import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_repair_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_enqueue_provider.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('DiveMediaSitting');

/// The held change of the Media card.
const String mediaKey = 'media';

const String _noteKey = 'media.held';
const String _writersKey = 'media.writers';
const String _createdKey = 'media.created';
const String _afterKey = 'media.after';
const String _undoKey = 'media.undo';

/// How a sitting's media are written at Save.
@immutable
class SittingMediaWriters {
  const SittingMediaWriters({
    required this.writeRows,
    required this.insertNetwork,
    required this.unlink,
    required this.replace,
    required this.drainDeletes,
    required this.enqueueUpload,
  });

  /// The app's own: the import service, the fetch pipeline, the unlink
  /// service (which deletes a row that belongs to nothing else, its remote
  /// delete held for the commit), the repair service (what it does outside
  /// the database left for the commit), and the media store's upload
  /// queue. Each is read only when
  /// it is used: a sitting starts on every unlock, and most never write
  /// media. [read] must outlive the page (the provider container's), since
  /// a save can finish after the page has gone.
  factory SittingMediaWriters.read(ProviderRead read) => SittingMediaWriters(
    writeRows: (prepared) async => [
      for (final row in await read(
        mediaImportServiceProvider,
      ).writePrepared(prepared))
        row.id,
    ],
    insertNetwork: (requests) =>
        read(networkFetchPipelineProvider).insertResolved(requests),
    unlink: (ids) async => MediaUnlinkService(
      repository: read(mediaRepositoryProvider),
      deleteMedia: (ids) => read(
        mediaDeletionCoordinatorProvider,
      ).deleteMultipleMedia(ids, holdRemoteDelete: true),
    ).unlinkFromDive(ids),
    replace: (proposals, afterCommit, onRollback) async => read(
      mediaRepairServiceProvider,
    ).apply(proposals, afterCommit: afterCommit, onRollback: onRollback),
    drainDeletes: () =>
        read(mediaDeletionCoordinatorProvider).drainHeldDeletes(),
    enqueueUpload: (mediaId) => read(mediaStoreEnqueueProvider)(mediaId),
  );

  final Future<List<String>> Function(List<PreparedMedia> prepared) writeRows;
  final Future<List<String>> Function(List<NetworkInsertRequest> requests)
  insertNetwork;
  final Future<void> Function(List<String> ids) unlink;

  /// Relinks [proposals], adding to the lists it is given what must wait
  /// for the commit, and what takes back its work outside the database (a
  /// new bookmark) if the write does not commit.
  final Future<void> Function(
    List<RepairProposal> proposals,
    List<Future<void> Function()> afterCommit,
    List<Future<void> Function()> onRollback,
  )
  replace;

  /// Lets the media store take the remote deletes an unlink held.
  final Future<void> Function() drainDeletes;
  final void Function(String mediaId) enqueueUpload;
}

/// What a sitting holds for the dive's media.
@immutable
class SittingMedia {
  const SittingMedia({
    this.added = const [],
    this.unlinked = const {},
    this.replaced = const {},
  });

  final List<HeldMediaAdd> added;

  /// Stored media unlinked from the dive.
  final Set<String> unlinked;

  /// Stored media whose link was replaced, by id.
  final Map<String, RepairProposal> replaced;

  bool get isEmpty => added.isEmpty && unlinked.isEmpty && replaced.isEmpty;
}

/// Keeps the writers the held write uses.
void holdSittingMedia(EditSession<Dive> session, SittingMediaWriters writers) {
  session.remember(_writersKey, writers);
}

SittingMedia sittingMedia(EditSession<Dive> session) =>
    (session.isDisposed ? null : session.recall<SittingMedia>(_noteKey)) ??
    const SittingMedia();

/// What makes two media the same file: the gallery asset, the local file
/// or the address it was fetched from. Null for one with none of them.
String? _sameFileKey(MediaItem m) => m.platformAssetId != null
    ? 'asset:${m.platformAssetId}'
    : m.localPath != null
    ? 'file:${m.localPath}'
    : m.url != null
    ? 'url:${m.url}'
    : null;

/// Adds what a picker handed the sitting. One the sitting already holds
/// (the gallery scan finding photos Add photos just picked, a file dropped
/// and then picked) is left out: the pickers check only what is stored.
void addMediaToSitting(EditSession<Dive> session, List<HeldMediaAdd> adds) {
  final held = sittingMedia(session);
  final seen = {for (final a in held.added) ?_sameFileKey(a.preview)};
  final fresh = [
    for (final a in adds)
      if (switch (_sameFileKey(a.preview)) {
        null => true,
        final key => seen.add(key),
      })
        a,
  ];
  if (fresh.isEmpty) return;
  _set(
    session,
    SittingMedia(
      added: [...held.added, ...fresh],
      unlinked: held.unlinked,
      replaced: held.replaced,
    ),
  );
}

/// Unlinks [ids] in the sitting; one added in it is simply dropped.
void unlinkMediaInSitting(EditSession<Dive> session, Set<String> ids) {
  final held = sittingMedia(session);
  final addedIds = {for (final a in held.added) a.preview.id};
  _set(
    session,
    SittingMedia(
      added: [
        for (final a in held.added)
          if (!ids.contains(a.preview.id)) a,
      ],
      unlinked: {...held.unlinked, ...ids.difference(addedIds)},
      replaced: {
        for (final e in held.replaced.entries)
          if (!ids.contains(e.key)) e.key: e.value,
      },
    ),
  );
}

/// Replaces stored media [id]'s link with [proposal]'s, at Save.
void replaceLinkInSitting(
  EditSession<Dive> session,
  String id,
  RepairProposal proposal,
) {
  final held = sittingMedia(session);
  _set(
    session,
    SittingMedia(
      added: held.added,
      unlinked: held.unlinked,
      replaced: {...held.replaced, id: proposal},
    ),
  );
}

void _set(EditSession<Dive> session, SittingMedia next) {
  if (session.isDisposed || session.isFrozen) return;
  final writers = session.recall<SittingMediaWriters>(_writersKey);
  if (writers == null) return;
  session.remember(_noteKey, next);
  if (next.isEmpty) {
    session.releaseWrite(mediaKey);
    return;
  }
  session.holdChange(
    mediaKey,
    cardId: DiveDetailSectionId.media.name,
    write: () => _write(session, writers),
  );
}

/// Writes the sitting's media inside the save's transaction: the rows, the
/// fetched network media, the unlinks (a row that belongs to nothing else
/// is deleted, its remote copy marked for deletion: a mark for a row that a
/// failed save keeps does nothing, by the media store's own rule), then the
/// replaced links. Uploads wait for the commit ([mediaAfterCommit]).
Future<void> _write(EditSession<Dive> session, SittingMediaWriters w) async {
  final undo = <Future<void> Function()>[];
  session
    ..remember(_createdKey, null)
    ..remember(_afterKey, null)
    // Kept from the start, so a write that fails partway can still be
    // taken back ([undoMediaOnFailure]).
    ..remember(_undoKey, undo);
  final after = <Future<void> Function()>[];
  final held = sittingMedia(session);
  final created = <String>[];
  final rows = [
    for (final a in held.added)
      if (a is HeldMediaRow) a.prepared,
  ];
  if (rows.isNotEmpty) created.addAll(await w.writeRows(rows));
  final network = [
    for (final a in held.added)
      if (a is HeldNetworkMedia) a.request,
  ];
  if (network.isNotEmpty) created.addAll(await w.insertNetwork(network));
  if (held.unlinked.isNotEmpty) {
    await w.unlink(held.unlinked.toList());
    after.add(w.drainDeletes);
  }
  if (held.replaced.isNotEmpty) {
    await w.replace(held.replaced.values.toList(), after, undo);
  }
  session
    ..remember(_createdKey, created)
    ..remember(_afterKey, after);
}

/// What must happen once the sitting's write has committed: an upload
/// queued for each row it wrote, the remote deletes its unlinks held, and
/// the uploads and cache drops of its relinks. Empty before a write went
/// through.
List<Future<void> Function()> mediaAfterCommit(EditSession<Dive> session) {
  final created = session.recall<List<String>>(_createdKey);
  final writers = session.recall<SittingMediaWriters>(_writersKey);
  if (created == null || writers == null) return const [];
  return [
    for (final id in created) () async => writers.enqueueUpload(id),
    ...?session.recall<List<Future<void> Function()>>(_afterKey),
  ];
}

/// Runs [write], the save of [session]; if it fails, takes back what the
/// sitting's media write did outside the database (a relink's new
/// bookmark), then lets the failure through. Each undo is on its own: one
/// that fails is logged and the rest still run.
Future<T> undoMediaOnFailure<T>(
  EditSession<Dive> session,
  Future<T> Function() write,
) async {
  try {
    return await write();
  } catch (_) {
    final undo = session.isDisposed
        ? null
        : session.recall<List<Future<void> Function()>>(_undoKey);
    if (!session.isDisposed) session.remember(_undoKey, null);
    for (final step in undo ?? const <Future<void> Function()>[]) {
      try {
        await step();
      } catch (error, stackTrace) {
        _log.warning(
          'Taking back a media write that did not commit failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    rethrow;
  }
}

/// [stored] as the sitting has it: unlinked ones gone, added ones in, in
/// the order the grid shows them (taken at, oldest first).
List<MediaItem> mediaInSitting(
  EditSession<Dive> session,
  List<MediaItem> stored,
) {
  final held = sittingMedia(session);
  if (held.isEmpty) return stored;
  final storedIds = {for (final m in stored) m.id};
  final all = [
    for (final m in stored)
      if (!held.unlinked.contains(m.id)) m,
    for (final a in held.added)
      if (!storedIds.contains(a.preview.id)) a.preview,
  ]..sort((a, b) => a.takenAt.compareTo(b.takenAt));
  return all;
}
