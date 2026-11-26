import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/marine_life/domain/entities/species_cover.dart';
import 'package:submersion/features/marine_life/domain/species_revamp_ids.dart';

/// The covers divers chose for species (issue #5027). Rows are keyed by
/// [speciesCoverId] and never deleted here: removing a cover nulls its
/// media, so a later choice never races a tombstone.
class SpeciesCoverRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _log = LoggerService.forClass(SpeciesCoverRepository);

  static const entityType = 'speciesCovers';

  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onAllTables([_db.speciesCovers]));

  /// [diverId]'s covers by species id. A removed cover is absent.
  Future<Map<String, SpeciesCover>> coversFor(String diverId) async {
    final rows = await (_db.select(
      _db.speciesCovers,
    )..where((t) => t.diverId.equals(diverId) & t.mediaId.isNotNull())).get();
    return {
      for (final r in rows)
        r.speciesId: SpeciesCover(
          speciesId: r.speciesId,
          mediaId: r.mediaId!,
          identificationId: r.identificationId,
        ),
    };
  }

  /// Makes [mediaId] (cropped to [identificationId] when given) the cover.
  Future<void> setCover({
    required String diverId,
    required String speciesId,
    required String mediaId,
    String? identificationId,
  }) => _write(diverId, speciesId, mediaId, identificationId);

  /// Removes the cover; the species falls back to its best crop.
  Future<void> clearCover({
    required String diverId,
    required String speciesId,
  }) => _write(diverId, speciesId, null, null);

  /// The latest write, which the next waits on: two quick cover choices
  /// land in the order they were made.
  Future<void> _lastWrite = Future<void>.value();

  Future<void> _write(
    String diverId,
    String speciesId,
    String? mediaId,
    String? identificationId,
  ) {
    final next = _lastWrite.then(
      (_) => _writeNow(diverId, speciesId, mediaId, identificationId),
    );
    _lastWrite = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<void> _writeNow(
    String diverId,
    String speciesId,
    String? mediaId,
    String? identificationId,
  ) async {
    try {
      final now = clock.now().millisecondsSinceEpoch;
      final id = speciesCoverId(diverId, speciesId);
      final existing = await (_db.select(
        _db.speciesCovers,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null && mediaId == null) return;
      await _db
          .into(_db.speciesCovers)
          .insertOnConflictUpdate(
            SpeciesCoversCompanion(
              id: Value(id),
              diverId: Value(diverId),
              speciesId: Value(speciesId),
              mediaId: Value(mediaId),
              identificationId: Value(identificationId),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to ${mediaId == null ? 'remove' : 'set'} a species cover',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
