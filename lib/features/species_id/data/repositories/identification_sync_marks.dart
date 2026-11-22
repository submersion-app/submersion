import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';

/// Publishes the marine life results a write changed (issue #4876): marks
/// runs, identifications and crops pending, stamps the diver's decisions
/// under their own clock, and tombstones what was deleted.
///
/// Called after the write commits, as the other media repositories do.
/// Never throws: a write that landed stays landed. A run or identification
/// that never got a clock is picked up by the next sync's backfill of
/// unstamped rows, and a crop by the named-crop backfill at launch
/// (`IdentificationCropStore.republishUnstamped`).
class IdentificationSyncMarks {
  IdentificationSyncMarks({SyncRepository? sync, DateTime Function()? now})
    : _sync = sync ?? SyncRepository(),
      _now = now ?? DateTime.now;

  final SyncRepository _sync;
  final DateTime Function() _now;
  final _log = LoggerService.forClass(IdentificationSyncMarks);

  static const runs = 'mediaIdentificationRuns';
  static const rows = 'mediaIdentifications';
  static const crops = 'mediaIdentificationCrops';

  int get _at => _now().millisecondsSinceEpoch;

  /// Runs (by media id) written or moved on.
  Future<void> runsWritten(List<String> mediaIds) => _pending(runs, mediaIds);

  /// Identifications whose machine fields were written: an analysis, a
  /// rename, a video chunk. Only the row clock moves.
  Future<void> rowsWritten(List<String> ids) => _pending(rows, ids);

  /// Identifications whose decision fields were written by the diver, or
  /// carried to a fresh row: only the decision clock moves, so a peer's
  /// newer machine fields still win and this decision still wins over
  /// theirs.
  Future<void> decisionsWritten(List<String> ids) =>
      _guard('decisions', () async {
        for (final id in ids.toSet()) {
          await _sync.markFactsPending(
            entityType: rows,
            recordId: id,
            localUpdatedAt: _at,
            group: SyncFactGroups.identificationDecision,
          );
        }
      });

  /// Crops (by identification id) written.
  Future<void> cropsWritten(List<String> identificationIds) =>
      _pending(crops, identificationIds);

  /// Tombstones what was deleted, so peers drop it too.
  Future<void> deleted({
    List<String> runMediaIds = const [],
    List<String> rowIds = const [],
    List<String> cropIds = const [],
  }) => _guard('deletions', () async {
    if (runMediaIds.isNotEmpty) {
      await _sync.logDeletions(entityType: runs, recordIds: runMediaIds);
    }
    if (rowIds.isNotEmpty) {
      await _sync.logDeletions(entityType: rows, recordIds: rowIds);
    }
    if (cropIds.isNotEmpty) {
      await _sync.logDeletions(entityType: crops, recordIds: cropIds);
    }
  });

  Future<void> _pending(String entityType, List<String> ids) => ids.isEmpty
      ? Future<void>.value()
      : _guard(
          entityType,
          () => _sync.markRecordsPending(
            entityType: entityType,
            recordIds: ids.toSet().toList(),
            localUpdatedAt: _at,
          ),
        );

  Future<void> _guard(String what, Future<void> Function() body) async {
    try {
      await body();
    } on Object catch (e, stackTrace) {
      _log.warning(
        'Could not publish marine life $what',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
