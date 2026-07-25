import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;

class BuddyConversionRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(BuddyConversionRepository);

  /// Converts a buddy into a dive center.
  ///
  /// Creates a new [DiveCenter] row with the buddy's name/contact info,
  /// re-links all dives that have this buddy (setting [diveCenterId] if null),
  /// and deletes the original buddy.
  Future<String> convertBuddyToDiveCenter(domain.Buddy buddy) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diveCenterId = _uuid.v4();

    try {
      _log.info(
        'Converting buddy ${buddy.id} (${buddy.name}) to dive center $diveCenterId',
      );

      await _db.transaction(() async {
        // 1. Create DiveCenter
        await _db
            .into(_db.diveCenters)
            .insert(
              DiveCentersCompanion(
                id: Value(diveCenterId),
                diverId: Value(buddy.diverId),
                name: Value(buddy.name),
                phone: Value(buddy.phone),
                email: Value(buddy.email),
                notes: Value(buddy.notes),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveCenters',
          recordId: diveCenterId,
          localUpdatedAt: now,
        );

        // 2. Find dives that have this buddy in the junction table
        final linkedDives = await (_db.select(
          _db.diveBuddies,
        )..where((t) => t.buddyId.equals(buddy.id))).get();
        final diveIds = linkedDives.map((d) => d.diveId).toSet().toList();

        // 3. Update those dives: set diveCenterId = newId where it's currently null
        if (diveIds.isNotEmpty) {
          final diveIdsToUpdate = (await (_db.select(
            _db.dives,
          )..where((t) => t.id.isIn(diveIds) & t.diveCenterId.isNull()))
                  .get())
              .map((d) => d.id)
              .toList(growable: false);

          if (diveIdsToUpdate.isNotEmpty) {
            await (_db.update(
              _db.dives,
            )..where(
                  (t) =>
                      t.id.isIn(diveIdsToUpdate) & t.diveCenterId.isNull(),
                )).write(
              DivesCompanion(
                diveCenterId: Value(diveCenterId),
                updatedAt: Value(now),
              ),
            );

            // markRecordPending only for dives that were updated
            for (final id in diveIdsToUpdate) {
              await _syncRepository.markRecordPending(
                entityType: 'dives',
                recordId: id,
                localUpdatedAt: now,
              );
            }
          }
        }

        // 4. Tombstone certifications
        // FK cascade removes the rows but doesn't write deletion_log entries.
        final certs = await (_db.select(
          _db.certifications,
        )..where((t) => t.buddyId.equals(buddy.id))).get();
        for (final cert in certs) {
          await _syncRepository.logDeletion(
            entityType: 'certifications',
            recordId: cert.id,
          );
        }

        // 5. Tombstone professional roles (issue #395)
        final roles = await (_db.select(
          _db.buddyRoles,
        )..where((t) => t.buddyId.equals(buddy.id))).get();
        for (final role in roles) {
          await _syncRepository.logDeletion(
            entityType: 'buddyRoles',
            recordId: role.id,
          );
        }

        // 6. Remove buddy from all dives (cleanup junction rows)
        final existingLinks = await (_db.select(
          _db.diveBuddies,
        )..where((t) => t.buddyId.equals(buddy.id))).get();
        await (_db.delete(
          _db.diveBuddies,
        )..where((t) => t.buddyId.equals(buddy.id))).go();
        for (final row in existingLinks) {
          await _syncRepository.logDeletion(
            entityType: 'diveBuddies',
            recordId: row.id,
          );
        }

        // 7. Delete the buddy
        await (_db.delete(
          _db.buddies,
        )..where((t) => t.id.equals(buddy.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'buddies',
          recordId: buddy.id,
        );
      });

      SyncEventBus.notifyLocalChange();
      _log.info(
        'Successfully converted buddy ${buddy.id} to dive center $diveCenterId',
      );
      return diveCenterId;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to convert buddy ${buddy.id} to dive center',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
