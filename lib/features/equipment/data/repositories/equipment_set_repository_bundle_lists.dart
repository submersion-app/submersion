part of 'equipment_set_repository_impl.dart';

/// The three ordered lists a set carries besides its gear (issue #4525).
typedef _BundleLists = ({
  List<String> includes,
  List<String> presets,
  List<String> configs,
});

const _BundleLists _noBundleLists = (
  includes: <String>[],
  presets: <String>[],
  configs: <String>[],
);

/// What a list write did, for the sync bookkeeping that follows the commit.
typedef _BundleListWrite = ({
  String entity,
  List<String> pendingIds,
  List<String> deletedIds,
});

/// One junction table under `equipment_sets`: which set column and which
/// target it pairs, and the table that keeps the target.
class _BundleListTable {
  const _BundleListTable({
    required this.entity,
    required this.sqlTable,
    required this.refColumn,
    required this.targetSqlTable,
  });

  /// The sync entity type, equal to the Drift getter.
  final String entity;
  final String sqlTable;
  final String refColumn;
  final String targetSqlTable;

  static const includes = _BundleListTable(
    entity: 'equipmentSetIncludes',
    sqlTable: 'equipment_set_includes',
    refColumn: 'included_set_id',
    targetSqlTable: 'equipment_sets',
  );
  static const presets = _BundleListTable(
    entity: 'equipmentSetWeightPresets',
    sqlTable: 'equipment_set_weight_presets',
    refColumn: 'preset_id',
    targetSqlTable: 'weight_presets',
  );
  static const configs = _BundleListTable(
    entity: 'equipmentSetCylinderConfigs',
    sqlTable: 'equipment_set_cylinder_configs',
    refColumn: 'config_id',
    targetSqlTable: 'cylinder_configs',
  );
}

/// Reads and writes of the included sets, weight presets and cylinder
/// configurations of a set. Each list is reconciled as a diff, like the
/// set's gear, so an unchanged save writes nothing.
extension _SetBundleListStore on EquipmentSetRepository {
  TableInfo _drift(_BundleListTable list) => switch (list.entity) {
    'equipmentSetIncludes' => _db.equipmentSetIncludes,
    'equipmentSetWeightPresets' => _db.equipmentSetWeightPresets,
    _ => _db.equipmentSetCylinderConfigs,
  };

  /// Each set's entries of one list, in order. Sets with none are absent.
  Future<Map<String, List<({String id, String ref, int sortOrder})>>> _rowsOf(
    _BundleListTable list,
    List<String> setIds,
  ) async {
    if (setIds.isEmpty) return const {};
    final placeholders = List.filled(setIds.length, '?').join(',');
    final rows = await _db
        .customSelect(
          'SELECT id, set_id, ${list.refColumn} AS ref, sort_order '
          'FROM ${list.sqlTable} WHERE set_id IN ($placeholders) '
          'ORDER BY sort_order, created_at, id',
          variables: [for (final id in setIds) Variable<String>(id)],
          readsFrom: {_drift(list)},
        )
        .get();
    final bySet = <String, List<({String id, String ref, int sortOrder})>>{};
    for (final row in rows) {
      bySet.putIfAbsent(row.read<String>('set_id'), () => []).add((
        id: row.read<String>('id'),
        ref: row.read<String>('ref'),
        sortOrder: row.read<int>('sort_order'),
      ));
    }
    return bySet;
  }

  /// The three lists of every set in [setIds], one query per list.
  Future<Map<String, _BundleLists>> _bundleListsFor(List<String> setIds) async {
    final includes = await _rowsOf(_BundleListTable.includes, setIds);
    final presets = await _rowsOf(_BundleListTable.presets, setIds);
    final configs = await _rowsOf(_BundleListTable.configs, setIds);
    List<String> refs(
      Map<String, List<({String id, String ref, int sortOrder})>> rows,
      String setId,
    ) => [for (final r in rows[setId] ?? const []) r.ref];
    return {
      for (final id in setIds)
        id: (
          includes: refs(includes, id),
          presets: refs(presets, id),
          configs: refs(configs, id),
        ),
    };
  }

  /// [ids] that still have a row in [sqlTable], order kept, duplicates
  /// dropped. A list can name something deleted since the form opened, and
  /// inserting it would fail the foreign key and abort the save.
  Future<List<String>> _existingIn(String sqlTable, List<String> ids) async {
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await _db
        .customSelect(
          'SELECT id FROM $sqlTable WHERE id IN ($placeholders)',
          variables: [for (final id in ids) Variable<String>(id)],
        )
        .get();
    final live = {for (final r in rows) r.read<String>('id')};
    final seen = <String>{};
    return [
      for (final id in ids)
        if (live.contains(id) && seen.add(id)) id,
    ];
  }

  /// Refuses a set that would break one-level nesting: including itself, a
  /// set of another diver or one that has includes, or gaining includes
  /// while another set includes it.
  ///
  /// Only the includes this save ADDS are judged. Two devices can each make
  /// a legal include that together nest two deep, and a set that sync left
  /// in that shape must still take a rename, or the edit that removes the
  /// include. The resolver reads one level whatever is stored.
  Future<void> _assertNesting(
    String setId,
    String? diverId,
    List<String> desired,
  ) async {
    if (desired.isEmpty) return;
    final stored = await _db
        .customSelect(
          'SELECT included_set_id FROM equipment_set_includes '
          'WHERE set_id = ?',
          variables: [Variable<String>(setId)],
        )
        .get();
    final held = {for (final r in stored) r.read<String>('included_set_id')};
    final includes = [
      for (final id in desired)
        if (!held.contains(id)) id,
    ];
    if (includes.isEmpty) return;
    if (includes.contains(setId)) {
      throw ArgumentError.value(setId, 'includedSetIds', 'includes itself');
    }
    final placeholders = List.filled(includes.length, '?').join(',');
    final variables = [for (final id in includes) Variable<String>(id)];
    final foreign = await _db
        .customSelect(
          'SELECT id FROM equipment_sets WHERE id IN ($placeholders) '
          'AND diver_id IS NOT ?',
          variables: [...variables, Variable<String>(diverId)],
        )
        .get();
    if (foreign.isNotEmpty) {
      throw ArgumentError.value(
        foreign.first.read<String>('id'),
        'includedSetIds',
        'belongs to another diver',
      );
    }
    final nested = await _db
        .customSelect(
          'SELECT set_id FROM equipment_set_includes '
          'WHERE set_id IN ($placeholders)',
          variables: variables,
        )
        .get();
    if (nested.isNotEmpty) {
      throw ArgumentError.value(
        nested.first.read<String>('set_id'),
        'includedSetIds',
        'already includes other sets',
      );
    }
    final outer = await _db
        .customSelect(
          'SELECT set_id FROM equipment_set_includes '
          'WHERE included_set_id = ? AND set_id != ?',
          variables: [Variable<String>(setId), Variable<String>(setId)],
        )
        .get();
    if (outer.isNotEmpty) {
      throw ArgumentError.value(
        setId,
        'includedSetIds',
        'is itself included by another set',
      );
    }
  }

  /// Reconciles one list of [setId] to [desired]. Runs inside the caller's
  /// transaction; the returned ids get their sync bookkeeping after it.
  Future<_BundleListWrite> _writeList(
    _BundleListTable list,
    String setId,
    List<String> desired,
    int now,
  ) async {
    final table = _drift(list);
    final live = await _existingIn(list.targetSqlTable, desired);
    final existing = (await _rowsOf(list, [setId]))[setId] ?? const [];
    final byRef = {for (final row in existing) row.ref: row};
    final pending = <String>[];
    final deleted = <String>[];

    for (final row in existing) {
      if (live.contains(row.ref)) continue;
      await _db.customUpdate(
        'DELETE FROM ${list.sqlTable} WHERE id = ?',
        variables: [Variable<String>(row.id)],
        updates: {table},
        updateKind: UpdateKind.delete,
      );
      deleted.add(row.id);
    }
    for (final (index, ref) in live.indexed) {
      final row = byRef[ref];
      if (row == null) {
        final id = _uuid.v4();
        await _db.customInsert(
          'INSERT INTO ${list.sqlTable} '
          '(id, set_id, ${list.refColumn}, sort_order, created_at) '
          'VALUES (?, ?, ?, ?, ?)',
          variables: [
            Variable<String>(id),
            Variable<String>(setId),
            Variable<String>(ref),
            Variable<int>(index),
            Variable<int>(now),
          ],
          updates: {table},
        );
        pending.add(id);
      } else if (row.sortOrder != index) {
        // A moved row is a changed row: it takes a fresh clock so a peer's
        // older copy cannot put it back.
        await _db.customUpdate(
          'UPDATE ${list.sqlTable} SET sort_order = ?, hlc = ? WHERE id = ?',
          variables: [
            Variable<int>(index),
            Variable<String>(await _syncRepository.issueRowClock()),
            Variable<String>(row.id),
          ],
          updates: {table},
          updateKind: UpdateKind.update,
        );
        pending.add(row.id);
      }
    }
    return (entity: list.entity, pendingIds: pending, deletedIds: deleted);
  }

  /// Every list row that goes when set [setId] is deleted: its own three
  /// lists, and the include rows of the sets that included it.
  Future<List<({String entity, String id})>> _bundleListRowsOfSet(
    String setId,
  ) async {
    final rows = <({String entity, String id})>[];
    for (final list in const [
      _BundleListTable.includes,
      _BundleListTable.presets,
      _BundleListTable.configs,
    ]) {
      final found = await _db
          .customSelect(
            'SELECT id FROM ${list.sqlTable} WHERE set_id = ?1'
            '${identical(list, _BundleListTable.includes) ? ' OR included_set_id = ?1' : ''}',
            variables: [Variable<String>(setId)],
          )
          .get();
      rows.addAll([
        for (final r in found) (entity: list.entity, id: r.read<String>('id')),
      ]);
    }
    return rows;
  }

  /// Writes all three lists of [set]. Inside the caller's transaction.
  Future<List<_BundleListWrite>> _writeBundleLists(
    String setId,
    domain.EquipmentSet set,
    int now,
  ) async {
    final includes = await _existingIn(
      _BundleListTable.includes.targetSqlTable,
      set.includedSetIds,
    );
    await _assertNesting(setId, set.diverId, includes);
    return [
      await _writeList(_BundleListTable.includes, setId, includes, now),
      await _writeList(
        _BundleListTable.presets,
        setId,
        set.weightPresetIds,
        now,
      ),
      await _writeList(
        _BundleListTable.configs,
        setId,
        set.cylinderConfigIds,
        now,
      ),
    ];
  }

  /// Marks and tombstones what [_writeBundleLists] wrote, after the commit.
  Future<void> _recordBundleListWrites(
    List<_BundleListWrite> writes,
    int now,
  ) async {
    for (final write in writes) {
      for (final id in write.pendingIds) {
        await _syncRepository.markRecordPending(
          entityType: write.entity,
          recordId: id,
          localUpdatedAt: now,
        );
      }
      for (final id in write.deletedIds) {
        await _syncRepository.logDeletion(
          entityType: write.entity,
          recordId: id,
        );
      }
    }
  }
}
