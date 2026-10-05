import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_delete_steps.dart';

/// Deletes [diverId]'s equipment locations, except a place a move on
/// surviving gear still names: that one moves to the owner of the gear
/// behind its earliest such move, stamped and marked for sync, so the
/// history keeps its name on every device. Run inside the caller's
/// transaction, after the diver's own gear and its moves are deleted, so
/// every move still standing belongs to gear that outlives the diver.
///
/// `equipment_location_moves.location_id` is SET NULL, so deleting a used
/// place would silently turn "it was at the shop" into "no location", and
/// the local SET NULL would never reach a peer.
Future<void> retireDiverEquipmentLocations(
  AppDatabase db,
  SyncRepository syncRepository,
  String diverId, {
  required int now,
}) async {
  final kept = await db
      .customSelect(
        'SELECT l.id AS id, (SELECT e.diver_id FROM equipment_location_moves m '
        'JOIN equipment e ON e.id = m.equipment_id WHERE m.location_id = l.id '
        'ORDER BY m.moved_at ASC, m.created_at ASC, m.id ASC LIMIT 1) AS heir '
        'FROM equipment_locations l WHERE l.diver_id = ? AND EXISTS '
        '(SELECT 1 FROM equipment_location_moves m WHERE m.location_id = l.id)',
        variables: [Variable.withString(diverId)],
      )
      .get();
  for (final r in kept) {
    final id = r.read<String>('id');
    await db.customStatement(
      'UPDATE equipment_locations SET diver_id = ?, updated_at = ? '
      'WHERE id = ?',
      [r.read<String?>('heir'), now, id],
    );
    await syncRepository.markRecordPending(
      entityType: 'equipmentLocations',
      recordId: id,
      localUpdatedAt: now,
    );
  }
  // No move references what is left, so the SET NULL takes nothing.
  final deletedIds = await diverRowIds(
    db,
    'SELECT id FROM equipment_locations WHERE diver_id = ?',
    [diverId],
  );
  if (deletedIds.isEmpty) return;
  await db.customStatement(
    'DELETE FROM equipment_locations WHERE diver_id = ?',
    [diverId],
  );
  await syncRepository.logDeletions(
    entityType: 'equipmentLocations',
    recordIds: deletedIds,
  );
}
