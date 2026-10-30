import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// Writes that fill a dive's details only where the dive has none, for a
/// cloud import bringing in what the diver logged in the source app
/// (issue #3491). The counterparts of [DiveRepository.fillNotesIfEmpty] and
/// [DiveRepository.addWeightIfNone]: the emptiness check sits in the same
/// SQL statement as the write, so nothing written in Submersion is ever
/// overwritten. Each returns whether it wrote, and a write that changed
/// something asks for a sync, as the species and dive center writes do.
class DiveFillIfEmptyRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();

  /// Whether dive [diveId] already has a dive center, so a caller can skip
  /// finding or creating one it would not link.
  Future<bool> hasDiveCenter(String diveId) async {
    final row = await _db
        .customSelect(
          'SELECT dive_center_id FROM dives WHERE id = ?',
          variables: [Variable.withString(diveId)],
        )
        .getSingleOrNull();
    return row?.read<String?>('dive_center_id') != null;
  }

  /// Links [centerId] to dive [diveId] when the dive has no dive center.
  Future<bool> linkDiveCenterIfNone(String diveId, String centerId) =>
      _updateDiveWhere(
        'dive_center_id = ?',
        [Variable.withString(centerId)],
        'dive_center_id IS NULL',
        diveId,
      );

  /// Writes [range] as dive [diveId]'s visibility, the shape a band pick in
  /// the edit form saves (issue #3226), when the dive records no visibility
  /// in any form: not the legacy band, a measurement or a range. A legacy
  /// `unknown` band counts as none, as it does in the edit form, and is
  /// cleared with the write.
  Future<bool> fillVisibilityRangeIfEmpty(
    String diveId,
    VisibilityRange range,
  ) => _updateDiveWhere(
    'visibility = NULL, visibility_min_meters = ?, visibility_max_meters = ?',
    [Variable(range.minM), Variable(range.maxM)],
    "(visibility IS NULL OR visibility = 'unknown') "
        'AND visibility_meters IS NULL '
        'AND visibility_min_meters IS NULL '
        'AND visibility_max_meters IS NULL',
    diveId,
  );

  /// Writes [strength] onto dive [diveId] when its current strength is empty.
  Future<bool> fillCurrentStrengthIfEmpty(
    String diveId,
    CurrentStrength strength,
  ) => _updateDiveWhere(
    'current_strength = ?',
    [Variable.withString(strength.name)],
    'current_strength IS NULL',
    diveId,
  );

  /// Adds each of [fields] to dive [diveId] whose label the dive does not
  /// have yet, ignoring case; a label repeated within [fields] is added once.
  /// New fields go after the dive's own. Returns how many were added.
  Future<int> addCustomFieldsIfMissing(
    String diveId,
    List<({String key, String value})> fields,
  ) async {
    if (fields.isEmpty) return 0;
    final existing = await (_db.select(
      _db.diveCustomFields,
    )..where((t) => t.diveId.equals(diveId))).get();
    final labels = {
      for (final row in existing) row.fieldKey.trim().toLowerCase(),
    };
    var sortOrder = existing.fold<int>(
      -1,
      (top, row) => row.sortOrder > top ? row.sortOrder : top,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    var added = 0;
    for (final field in fields) {
      if (!labels.add(field.key.trim().toLowerCase())) continue;
      final id = _uuid.v4();
      sortOrder++;
      await _db
          .into(_db.diveCustomFields)
          .insert(
            DiveCustomFieldsCompanion(
              id: Value(id),
              diveId: Value(diveId),
              fieldKey: Value(field.key),
              fieldValue: Value(field.value),
              sortOrder: Value(sortOrder),
              createdAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveCustomFields',
        recordId: id,
        localUpdatedAt: now,
      );
      added++;
    }
    if (added > 0) await _markDiveChanged(diveId, now);
    return added;
  }

  /// `UPDATE dives SET <set>, updated_at WHERE id AND <guard>`, marking the
  /// dive pending only when a row changed.
  Future<bool> _updateDiveWhere(
    String set,
    List<Variable> setVariables,
    String guard,
    String diveId,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final changed = await _db.customUpdate(
      'UPDATE dives SET $set, updated_at = ? WHERE id = ? AND $guard',
      variables: [
        ...setVariables,
        Variable.withInt(now),
        Variable.withString(diveId),
      ],
      updates: {_db.dives},
    );
    if (changed == 0) return false;
    await _syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return true;
  }

  Future<void> _markDiveChanged(String diveId, int now) async {
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }
}
