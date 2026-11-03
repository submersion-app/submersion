part of 'write_planner.dart';

/// How a preview treats a child entry, such as a tank, which takes its
/// owner and version from the record it belongs to, and how it checks the
/// references a change sets.
extension _ChildRules on _Pass {
  /// Reads `id`, `diver_id`, `updated_at` and `parent_id` of [entry]'s rows,
  /// aliased `r`. A child's owner and version are its parent's.
  String _rowSelect(WritableEntry entry) {
    final parent = entry.parent;
    if (parent == null) {
      return 'SELECT r.id, r.diver_id, r.updated_at, NULL AS parent_id '
          'FROM ${entry.table} r';
    }
    return 'SELECT r.id, p.diver_id, p.updated_at, r.${parent.field} AS '
        'parent_id FROM ${entry.table} r JOIN ${_parentTable(entry)} p '
        'ON p.id = r.${parent.field}';
  }

  String _parentTable(WritableEntry entry) =>
      writes.named(entry.parent!.entity)!.table;

  /// Who a create belongs to. A record of its own takes the profile the set
  /// names, or the active one. A child takes its parent's owner, and a
  /// profile the set names must be that one.
  Future<({String diverId, String? parentId, PlanBlock? block})> _owner(
    CreateOp op,
    WritableEntry entry,
    Map<String, Object?> values,
  ) async {
    final parent = entry.parent;
    if (parent == null) {
      return (
        diverId: await resolveDiver(op.diverId),
        parentId: null,
        block: null,
      );
    }
    final parentId = values[parent.field]! as String;
    Future<({String diverId, String? parentId, PlanBlock? block})> blocked(
      BlockReason reason,
      String detail,
    ) async =>
        (diverId: '', parentId: parentId, block: PlanBlock(reason, detail));
    if (_deleted.contains((parent.entity, parentId))) {
      return blocked(
        BlockReason.referenceDeleted,
        '${parent.field} refers to $parentId, which this set deletes.',
      );
    }
    final table = _parentTable(entry);
    final row = await db
        .customSelect(
          'SELECT diver_id, updated_at FROM $table WHERE id = ?',
          variables: [Variable.withString(parentId)],
        )
        .getSingleOrNull();
    if (row == null) {
      return blocked(
        BlockReason.unknownReference,
        '${parent.field}: nothing has the id $parentId.',
      );
    }
    final ownerId = row.readNullable<String>('diver_id');
    if (op.diverId != null && op.diverId != ownerId) {
      return blocked(
        BlockReason.invalidValue,
        'A ${op.entity} record belongs to the profile of its ${parent.entity} '
        'record, here $ownerId. Leave diver_id out or name that profile.',
      );
    }
    // A parent deleted after the preview refuses the plan.
    markers.add(
      RecordMarker(
        table: table,
        id: parentId,
        updatedAt: row.read<int>('updated_at'),
      ),
    );
    return (
      diverId: ownerId ?? await resolveDiver(null),
      parentId: parentId,
      block: null,
    );
  }

  /// What apply compares with the record as the preview read it. A child has
  /// no version of its own, so its parent's stands in, and the child's own
  /// document is compared too: a merge can change the child row alone.
  RecordMarker _marker(
    WritableEntry entry,
    String id,
    _Row row,
    Map<String, Object?> document, {
    Map<String, Set<String>> relations = const {},
    required String footprint,
    required Future<String> Function() readFootprint,
  }) {
    Future<Set<String>> readRelation(String relation) =>
        entry.currentRelation(id, relation);
    if (entry.parent == null) {
      return RecordMarker(
        table: entry.table,
        id: id,
        updatedAt: row.updatedAt,
        relations: relations,
        readRelation: readRelation,
        footprint: footprint,
        readFootprint: readFootprint,
      );
    }
    return RecordMarker(
      table: _parentTable(entry),
      id: row.parentId!,
      updatedAt: row.updatedAt,
      relations: relations,
      readRelation: readRelation,
      footprint: '$footprint ${jsonEncode(document)}',
      readFootprint: () async {
        final now = await _document(entry, id, row.ownerId);
        return '${await readFootprint()} ${jsonEncode(now)}';
      },
    );
  }

  /// Blocks a change to a child whose parent the set deletes, as the delete
  /// takes the child with it. True when it blocked.
  bool _orphaned(ChangeOp op, WritableEntry entry, _Row row, ChangeKind kind) {
    final parent = entry.parent;
    if (parent == null || !_deleted.contains((parent.entity, row.parentId))) {
      return false;
    }
    _add(
      op,
      entry,
      kind: kind,
      id: switch (op) {
        UpdateOp(:final id) || DeleteOp(:final id) => id,
        CreateOp() => null,
      },
      parentId: row.parentId,
      block: PlanBlock(
        BlockReason.referenceDeleted,
        'This set deletes ${parent.entity} ${row.parentId}, which takes this '
        'record with it.',
      ),
    );
    return true;
  }

  /// A block when an update changes a field only a create may set.
  PlanBlock? _fixed(WritableEntry entry, _Parsed parsed) {
    final fixed = [
      for (final key in {?entry.parent?.field, ...entry.createOnly})
        if (parsed.changes.containsKey(key)) key,
    ];
    if (fixed.isEmpty) return null;
    return PlanBlock(
      BlockReason.notPermitted,
      '${fixed.join(', ')} cannot change once a ${entry.name} record exists. '
      'Delete it and create another.',
    );
  }

  /// The references a change sets, other than a child's parent, which is
  /// checked when its owner is worked out.
  Iterable<({String key, String refEntity, String id})> _fieldRefs(
    WritableEntry entry,
    Map<String, Object?> values,
  ) sync* {
    for (final MapEntry(:key, :value) in values.entries) {
      final codec = entry.fields[key];
      if (codec is ReferenceCodec &&
          value is String &&
          key != entry.parent?.field) {
        yield (key: key, refEntity: codec.refEntity, id: value);
      }
    }
  }

  /// Checks each reference a change sets, as a relation's links are checked.
  Future<PlanBlock?> _checkFieldRefs(
    WritableEntry entry,
    Map<String, Object?> values,
    String? ownerId,
  ) async {
    for (final ref in _fieldRefs(entry, values)) {
      final block = await _checkRefs(ref.key, ref.refEntity, {ref.id}, ownerId);
      if (block != null) return block;
    }
    return null;
  }

  Future<void> _markFieldRefs(
    WritableEntry entry,
    Map<String, Object?> values,
  ) async {
    for (final ref in _fieldRefs(entry, values)) {
      await _markReference(records.named(ref.refEntity).table, ref.id);
    }
  }
}
