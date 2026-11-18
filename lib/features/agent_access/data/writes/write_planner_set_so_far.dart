part of 'write_planner.dart';

/// What the changes before the one being planned do, for its rules: the
/// fields they write, the records they delete, create, unlink and touch, and
/// the records their side effects rewrite.
extension _SetSoFarRules on _Pass {
  /// What the set does before the change being planned, for its rules.
  SetSoFar get _soFar => SetSoFar(
    deleted: _deletedSoFar,
    values: _valuesSoFar,
    unlinked: _unlinkedSoFar,
    created: _createdSoFar,
    touched: _touchedSoFar,
  );

  /// [_soFar] as it stands now, for a read that runs again at apply, after
  /// the later changes of the set have been planned.
  SetSoFar get _soFarSnapshot => SetSoFar(
    deleted: {
      for (final MapEntry(:key, :value) in _deletedSoFar.entries)
        key: {...value},
    },
    values: {..._valuesSoFar},
    unlinked: {
      for (final MapEntry(:key, :value) in _unlinkedSoFar.entries)
        key: {
          for (final MapEntry(key: entity, value: ids) in value.entries)
            entity: {...ids},
        },
    },
    created: {
      for (final MapEntry(:key, :value) in _createdSoFar.entries)
        key: [...value],
    },
    touched: {
      for (final MapEntry(:key, :value) in _touchedSoFar.entries)
        key: {...value},
    },
  );

  /// Notes that a change the plan keeps writes [id] of [entry], and the
  /// record it belongs to, [parentId], for the rules of the changes after it.
  void _touch(WritableEntry entry, String? id, String? parentId) {
    if (id != null) (_touchedSoFar[entry.name] ??= {}).add(id);
    if ((entry.parent?.entity, parentId) case (final parent?, final owner?)) {
      (_touchedSoFar[parent] ??= {}).add(owner);
    }
  }

  /// A block when an earlier change's side effects rewrite or delete [id] of
  /// [entry], or the record it belongs to, [parentId]: this change would be
  /// planned against values the apply replaces first.
  PlanBlock? _rewrittenFirst(
    WritableEntry entry,
    String? id,
    String? parentId,
  ) {
    final by =
        (id == null ? null : _rewritten[(entry.name, id)]) ??
        switch ((entry.parent?.entity, parentId)) {
          (final parent?, final owner?) => _rewritten[(parent, owner)],
          _ => null,
        };
    if (by == null) return null;
    return PlanBlock(
      BlockReason.notPermitted,
      'operation $by of this set rewrites this record through its own '
      'rules; change it in a set of its own after that one.',
    );
  }

  /// Notes what an update the plan keeps writes and unlinks, for the rules
  /// of the changes after it.
  void _recordSoFar(
    UpdateOp op,
    WritableEntry entry,
    Map<String, Object?> values,
    Map<String, RelationDelta> deltas,
    SideEffects effects,
    String? parentId,
  ) {
    final detached = effects.detached;
    _valuesSoFar[(op.entity, op.id)] = values;
    _touch(entry, op.id, parentId);
    for (final MapEntry(key: entity, value: ids) in effects.rewrites.entries) {
      (_touchedSoFar[entity] ??= {}).addAll(ids);
      for (final id in ids) {
        _rewritten.putIfAbsent((entity, id), () => op.index);
      }
    }
    for (final MapEntry(key: entity, value: ids) in detached.entries) {
      ((_unlinkedSoFar[(op.entity, op.id)] ??= {})[entity] ??= {}).addAll(ids);
    }
    for (final MapEntry(key: name, value: delta) in deltas.entries) {
      final target = entry.relations[name]!.refEntity;
      (_touchedSoFar[target] ??= {}).addAll({...delta.add, ...delta.remove});
      for (final id in delta.remove) {
        ((_unlinkedSoFar[(target, id)] ??= {})[op.entity] ??= {}).add(op.id);
      }
    }
  }
}
