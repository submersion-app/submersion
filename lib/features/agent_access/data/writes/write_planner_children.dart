part of 'write_planner.dart';

/// [id] read through [reader] as [diverId] sees it, or an empty document when
/// it has gone. Top level, so a marker that reads again at apply holds the
/// reader and not the preview pass, whose database a plan must not keep
/// alive (see [WritePlan.previewedOn]).
Future<Map<String, Object?>> _readDocument(
  RecordEntry reader,
  String id,
  String diverId,
) async =>
    (await reader.read([
      id,
    ], RecordLoad(include: const {}, diverId: diverId)))[id] ??
    const {};

/// Whether [table] still holds [id], read from the current database for the
/// same reason.
Future<String> _presence(String table, String id) async {
  final row = await DatabaseService.instance.database
      .customSelect(
        'SELECT 1 FROM $table WHERE id = ?',
        variables: [Variable.withString(id)],
      )
      .getSingleOrNull();
  return row == null ? 'gone' : 'present';
}

/// How a preview treats a child entry, such as a tank, which takes its
/// owner and version from the record it belongs to, and how it checks the
/// references a change sets.
extension _ChildRules on _Pass {
  /// Reads `id`, `diver_id`, `updated_at` and `parent_id` of [entry]'s rows,
  /// aliased `r`. A child's owner and version are its parent's.
  Future<String> _rowSelect(WritableEntry entry) async {
    final parent = entry.parent;
    if (parent == null) {
      // A record no diver owns, such as a species, has no owner column, and
      // one with no version column is marked by its document instead.
      final columns = await _columnsOf(entry.table);
      final owner = columns.contains('diver_id')
          ? 'r.diver_id'
          : 'NULL AS diver_id';
      final version = columns.contains('updated_at')
          ? 'r.updated_at'
          : '0 AS updated_at';
      return 'SELECT r.id, $owner, $version, NULL AS parent_id '
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
  /// profile the set names must be that one. [diverId] is null only when
  /// [block] is set.
  Future<({String? diverId, String? parentId, PlanBlock? block})> _owner(
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
    ({String? diverId, String? parentId, PlanBlock? block}) blocked(
      BlockReason reason,
      String detail,
    ) => (diverId: null, parentId: parentId, block: PlanBlock(reason, detail));
    if (_deleted.contains((parent.entity, parentId))) {
      return blocked(
        BlockReason.referenceDeleted,
        '${parent.field} refers to $parentId, which this set deletes.',
      );
    }
    final table = _parentTable(entry);
    final row = await db
        .customSelect(
          'SELECT diver_id FROM $table WHERE id = ?',
          variables: [Variable.withString(parentId)],
        )
        .getSingleOrNull();
    if (row == null) {
      return blocked(
        BlockReason.unknownReference,
        '${parent.field}: nothing has the id $parentId.',
      );
    }
    // A parent with no owner, as an old dive can be, takes the one named.
    final ownerId = row.readNullable<String>('diver_id');
    if (ownerId != null && op.diverId != null && op.diverId != ownerId) {
      return blocked(
        BlockReason.invalidValue,
        'A ${op.entity} record belongs to the profile of its ${parent.entity} '
        'record, here $ownerId. Leave diver_id out or name that profile.',
      );
    }
    // A parent deleted after the preview refuses the plan.
    await _markReference(table, parentId);
    return (
      diverId: ownerId ?? await resolveDiver(op.diverId),
      parentId: parentId,
      block: null,
    );
  }

  /// What apply compares with the record as the preview read it. A child has
  /// no version of its own, so its parent's stands in, and the child's own
  /// document is compared too: a merge can change the child row alone.
  Future<RecordMarker> _marker(
    WritableEntry entry,
    String id,
    _Row row,
    Map<String, Object?> document, {
    Map<String, Set<String>> relations = const {},
    required String footprint,
    required Future<String> Function() readFootprint,
  }) async {
    Future<Set<String>> readRelation(String relation) =>
        entry.currentRelation(id, relation);
    if (entry.parent == null && !await _versioned(entry.table)) {
      // No version to compare, so the record's own document is the marker,
      // as a child's is.
      final reader = records.named(entry.name);
      final diverId = row.ownerId ?? await resolveDiver(null);
      return RecordMarker(
        table: entry.table,
        id: id,
        updatedAt: null,
        versioned: false,
        relations: relations,
        readRelation: readRelation,
        footprint: '$footprint ${jsonEncode(document)}',
        readFootprint: () async {
          final now = await _readDocument(reader, id, diverId);
          return '${await readFootprint()} ${jsonEncode(now)}';
        },
      );
    }
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
    final reader = records.named(entry.name);
    final diverId = row.ownerId ?? await resolveDiver(null);
    return RecordMarker(
      table: _parentTable(entry),
      id: row.parentId!,
      updatedAt: row.updatedAt,
      relations: relations,
      readRelation: readRelation,
      footprint: '$footprint ${jsonEncode(document)}',
      readFootprint: () async {
        final now = await _readDocument(reader, id, diverId);
        return '${await readFootprint()} ${jsonEncode(now)}';
      },
    );
  }

  /// What a diver knows a child's parent by, and the parent's date, so a
  /// plan says which dive a tank change is on. Both null for a record of its
  /// own.
  Future<({String? title, String? date})> _parentContext(
    WritableEntry entry,
    String? parentId,
    String? ownerId,
  ) async {
    final parent = entry.parent;
    if (parent == null || parentId == null) return (title: null, date: null);
    final document = await _readDocument(
      records.named(parent.entity),
      parentId,
      ownerId ?? await resolveDiver(null),
    );
    return (
      title: writes.named(parent.entity)?.titleOf(document),
      date: document['date_time'] as String?,
    );
  }

  /// The names of the records [fields]' references point at, by id, so a
  /// diver reads a dive's or a species' name rather than its id.
  Future<Map<String, String>> _referenceNames(
    WritableEntry entry,
    Map<String, FieldChange> fields,
    String? ownerId,
  ) async {
    final names = <String, String>{};
    for (final MapEntry(:key, :value) in fields.entries) {
      final codec = entry.fields[key];
      if (codec is! ReferenceCodec) continue;
      for (final id in {value.oldValue, value.newValue}.whereType<String>()) {
        final document = await _readDocument(
          records.named(codec.refEntity),
          id,
          ownerId ?? await resolveDiver(null),
        );
        final name =
            writes.named(codec.refEntity)?.titleOf(document) ??
            document['name'] as String? ??
            document['common_name'] as String?;
        if (name != null) names[id] = name;
      }
    }
    return names;
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

  /// A block when a [kind] change of [entry] writes its parent and the set
  /// also updates the same fields of that parent.
  PlanBlock? _parentWritten(
    WritableEntry entry,
    String? parentId,
    ChangeKind kind,
  ) {
    final parent = entry.parent;
    final named = _updatedFields[(parent?.entity, parentId)];
    if (parent == null ||
        !entry.writesParent.contains(kind) ||
        named == null ||
        named.intersection(entry.parentFieldsWritten).isEmpty) {
      return null;
    }
    return PlanBlock(
      BlockReason.referenceChanged,
      'This ${kind.name} also writes ${parent.entity} $parentId, which '
      'another operation in this set changes. Put them in sets of their '
      'own.',
    );
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
