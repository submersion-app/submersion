part of 'write_planner.dart';

/// How a pass reads the links an update changes and checks what they
/// point at.
extension _Relations on _Pass {
  Future<_Links> _relations(
    UpdateOp op,
    WritableEntry entry,
    String? ownerId,
  ) async {
    final deltas = <String, RelationDelta>{};
    final current = <String, Set<String>>{};
    for (final MapEntry(key: name, value: change) in op.relations.entries) {
      final spec = entry.relations[name];
      if (spec == null) {
        return _Links.blocked(
          PlanBlock(
            BlockReason.unknownField,
            '$name is not a relation of ${entry.name}. '
            'These are: ${entry.relations.keys.join(', ')}.',
          ),
        );
      }
      final stored = current[name] = await entry.currentRelation(op.id, name);
      // A link an earlier change in the set takes away, such as a tag whose
      // scope closes, is gone by the time this change runs.
      final links = {
        for (final id in stored)
          if (!(_unlinkedSoFar[(spec.refEntity, id)]?[op.entity]?.contains(
                op.id,
              ) ??
              false))
            id,
      };
      final delta = _delta(change, links, spec);
      if (delta == null) {
        return _Links.blocked(
          PlanBlock(BlockReason.invalidValue, '$name takes one id.'),
        );
      }
      final block = await _checkRefs(
        name,
        spec.refEntity,
        delta.add,
        ownerId,
        copiesTarget: spec.copiesTarget,
      );
      if (block != null) return _Links.blocked(block);
      if (!delta.isEmpty) deltas[name] = delta;
    }
    return _Links(deltas: deltas, current: current);
  }

  /// What [change] means against [links], or null when a single relation is
  /// handed more than one id.
  RelationDelta? _delta(
    RelationChange change,
    Set<String> links,
    RelationSpec spec,
  ) {
    final wanted = change.set?.toSet();
    final add = (wanted ?? change.add.toSet()).difference(links);
    if (spec.single && (wanted ?? add).length > 1) return null;
    final remove = wanted != null
        ? links.difference(wanted)
        : change.remove.toSet().intersection(links);
    return RelationDelta(
      add: add,
      // A single link has one place, so a new one takes the old one's.
      remove: spec.single && add.isNotEmpty ? links : remove,
    );
  }

  /// Whether [ids], which [name] points at records of [refEntity] with, may
  /// be used by [ownerId]. [copiesTarget] as [RelationSpec.copiesTarget].
  Future<PlanBlock?> _checkRefs(
    String name,
    String refEntity,
    Set<String> ids,
    String? ownerId, {
    bool copiesTarget = false,
  }) async {
    if (ids.isEmpty) return null;
    final deleted = ids.where((id) => _deleted.contains((refEntity, id)));
    if (deleted.isNotEmpty) {
      return PlanBlock(
        BlockReason.referenceDeleted,
        '$name refers to ${deleted.join(', ')}, which this set deletes.',
      );
    }
    final changed = copiesTarget
        ? ids.where((id) => _changedSoFar.contains((refEntity, id)))
        : const <String>[];
    if (changed.isNotEmpty) {
      return PlanBlock(
        BlockReason.referenceChanged,
        '$name copies values from ${changed.join(', ')}, which an earlier '
        'operation in this set changes. Link it in a change set of its own.',
      );
    }
    final ref = records.named(refEntity);
    final diverId = ownerId ?? await resolveDiver(null);
    final visible = await RecordReader(
      db,
    ).visibleIds(ref, ids.toList(), diverId);
    final hidden = ids.difference(visible.toSet());
    if (hidden.isEmpty) return null;
    final existing = await _existing(ref, hidden);
    final strangers = hidden.intersection(existing);
    if (strangers.isNotEmpty) {
      return PlanBlock(
        BlockReason.otherProfileReference,
        '$name: ${strangers.join(', ')} belongs to another profile.',
      );
    }
    return PlanBlock(
      BlockReason.unknownReference,
      '$name: nothing has the id ${hidden.join(', ')}.',
    );
  }

  Future<Set<String>> _existing(RecordEntry ref, Set<String> ids) async {
    final found = <String>{};
    for (final chunk in seriesIdChunks(ids.toList())) {
      final marks = List.filled(chunk.length, '?').join(', ');
      final rows = await db
          .customSelect(
            'SELECT id FROM ${ref.table} WHERE id IN ($marks)',
            variables: [for (final id in chunk) Variable.withString(id)],
          )
          .get();
      found.addAll(rows.map((row) => row.read<String>('id')));
    }
    return found;
  }
}
