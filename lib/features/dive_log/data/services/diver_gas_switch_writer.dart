import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

/// The one write behind the gas switch editor (issue #32).
///
/// The editor shows a dive's switches and hands back the list as the diver
/// left it; this diffs that list against the rows the editor loaded and
/// applies the difference in one transaction. The dive is then marked as
/// having a diver-owned switch list, which a re-parse and a file resync
/// leave alone, and its stored safety review is dropped so it is rebuilt
/// from the new switches.
class DiverGasSwitchWriter {
  /// A [db] given without [sync] binds the sync repository to that same
  /// database, so rows and their pending records never split across two.
  DiverGasSwitchWriter({AppDatabase? db, SyncRepository? sync})
    : _db = db ?? DatabaseService.instance.database,
      _sync = sync ?? SyncRepository(database: db);

  final AppDatabase _db;
  final SyncRepository _sync;
  static const _uuid = Uuid();

  /// Replaces the switches the editor showed with [switches]. [loadedIds]
  /// are the ids the editor loaded: an id in both is updated (timestamp,
  /// tank and depth; its computer is untouched), one only in [switches] is
  /// inserted with no computer, one only in [loadedIds] is deleted and
  /// tombstoned, even when a removed cylinder already cascaded it away.
  /// Switches the editor did not load (another computer's) are never
  /// touched. Returns false, writing nothing, when nothing differs.
  Future<bool> save({
    required String diveId,
    required List<GasSwitch> switches,
    required Set<String> loadedIds,
    DateTime? now,
  }) async {
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
    // The diff is computed inside the transaction it is applied in, so a
    // write that lands between the read and the writes cannot be undone
    // by a stale comparison.
    final changed = await _db.transaction(() async {
      final stored = <String, GasSwitche>{
        if (loadedIds.isNotEmpty)
          for (final row
              in await (_db.select(_db.gasSwitches)..where(
                    (t) => t.diveId.equals(diveId) & t.id.isIn(loadedIds),
                  ))
                  .get())
            row.id: row,
      };

      final inserts = <GasSwitch>[];
      final updates = <GasSwitch>[];
      final keptIds = <String>{};
      for (final sw in switches) {
        final row = stored[sw.id];
        if (row == null) {
          inserts.add(sw);
          continue;
        }
        keptIds.add(sw.id);
        if (row.timestamp != sw.timestamp ||
            row.tankId != sw.tankId ||
            row.depth != sw.depth) {
          updates.add(sw);
        }
      }
      // A loaded id the list no longer holds is a delete whether or not its
      // row is still there: removing a cylinder cascades its switches away
      // before this runs, and a peer still needs the tombstone.
      final deletes = [
        for (final id in loadedIds)
          if (!keptIds.contains(id) && !switches.any((s) => s.id == id)) id,
      ];
      if (inserts.isEmpty && updates.isEmpty && deletes.isEmpty) return false;

      for (final sw in inserts) {
        final id = sw.id.isEmpty ? _uuid.v4() : sw.id;
        await _db
            .into(_db.gasSwitches)
            .insert(
              GasSwitchesCompanion(
                id: Value(id),
                diveId: Value(diveId),
                timestamp: Value(sw.timestamp),
                tankId: Value(sw.tankId),
                depth: Value(sw.depth),
                createdAt: Value(at),
                computerId: const Value(null),
              ),
            );
        await _sync.markRecordPending(
          entityType: 'gasSwitches',
          recordId: id,
          localUpdatedAt: at,
        );
      }
      for (final sw in updates) {
        await (_db.update(
          _db.gasSwitches,
        )..where((t) => t.id.equals(sw.id))).write(
          GasSwitchesCompanion(
            timestamp: Value(sw.timestamp),
            tankId: Value(sw.tankId),
            depth: Value(sw.depth),
          ),
        );
        await _sync.markRecordPending(
          entityType: 'gasSwitches',
          recordId: sw.id,
          localUpdatedAt: at,
        );
      }
      for (final id in deletes) {
        await (_db.delete(_db.gasSwitches)..where((t) => t.id.equals(id))).go();
        await _sync.logDeletion(entityType: 'gasSwitches', recordId: id);
      }

      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(
          updatedAt: Value(at),
          gasSwitchesEdited: const Value(true),
        ),
      );
      await _sync.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: at,
      );
      // The review graded the old switches; drop it so the next view
      // recomputes, as re-parse and a profile edit do.
      await SafetyFindingsRepository.clearReviewForDive(_db, _sync, diveId);
      return true;
    });
    if (!changed) return false;
    SyncEventBus.notifyLocalChange();
    return true;
  }
}
