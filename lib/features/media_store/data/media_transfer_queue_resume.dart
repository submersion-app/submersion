part of 'media_transfer_queue_repository.dart';

/// The resumable sessions a re-upload or a Transfers delete is about to
/// drop, read before the rows go so their provider-side sessions can be
/// abandoned (storage GC design, leak 4).
extension MediaTransferQueueResume on MediaTransferQueueRepository {
  /// Upload rows for [mediaId] that hold a resumable session, read before a
  /// re-upload drops them so their provider-side sessions can be abandoned
  /// (storage GC design, leak 4).
  Future<List<DroppedResume>> resumeStatesFor(String mediaId) async {
    final rows =
        await (_db.select(_db.mediaTransferQueue)..where(
              (t) =>
                  t.mediaId.equals(mediaId) &
                  t.direction.equals('upload') &
                  // A transferring row's session is live: the pipeline is
                  // pushing parts into it right now.
                  t.state.equals('transferring').not() &
                  t.resumeStateJson.isNotNull(),
            ))
            .get();
    return [
      for (final r in rows)
        // A row a drain has claimed still reads pending, but its session is
        // the one the drain is about to resume.
        if (!_held.contains(r.id))
          DroppedResume(
            mediaId: r.mediaId,
            resumeStateJson: r.resumeStateJson!,
          ),
    ];
  }

  /// [enqueueReupload], returning the resumable sessions of the rows it
  /// dropped so the caller can abandon them. Read in the same transaction
  /// as the drop, and never a row a drain holds: its session is live.
  Future<List<DroppedResume>> reenqueueForReupload({
    required String mediaId,
    required String overrideLevel,
  }) => _db.transaction(() async {
    final dropped = await resumeStatesFor(mediaId);
    await enqueueReupload(mediaId: mediaId, overrideLevel: overrideLevel);
    return dropped;
  });

  /// Deletes row [id] (the Transfers page's delete) and returns its
  /// resumable session to abandon, or null; same rules as
  /// [reenqueueForReupload].
  Future<DroppedResume?> deleteDroppingSession(int id) =>
      _db.transaction(() async {
        final dropped = await resumeStateOf(id);
        await delete(id);
        return dropped;
      });

  /// The resumable session row [id] holds, or null; read before [delete].
  /// Null for a `transferring` row too, or one a drain has claimed: its
  /// session is live, and abandoning it would abort the upload the worker
  /// is running.
  Future<DroppedResume?> resumeStateOf(int id) async {
    final row = await (_db.select(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final json = row?.resumeStateJson;
    if (row == null ||
        json == null ||
        row.direction != 'upload' ||
        row.state == 'transferring' ||
        _held.contains(row.id)) {
      return null;
    }
    return DroppedResume(mediaId: row.mediaId, resumeStateJson: json);
  }
}

/// A resumable upload session whose queue row is being dropped.
class DroppedResume {
  const DroppedResume({required this.mediaId, required this.resumeStateJson});

  final String mediaId;
  final String resumeStateJson;
}
