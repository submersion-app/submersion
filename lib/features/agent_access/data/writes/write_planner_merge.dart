part of 'write_planner.dart';

/// A delete that names `merge_into`: the merged record goes and the survivor
/// takes over its links, as the app's merge does.
extension _MergeRules on _Pass {
  /// A block when [op] cannot merge into its survivor, null when it can. The
  /// survivor's row was read with the set's own records.
  PlanBlock? _mergeBlock(DeleteOp op, WritableEntry entry, _Row row) {
    final into = op.mergeInto!;
    if (!entry.mergeable) {
      return PlanBlock(
        BlockReason.notPermitted,
        '${entry.name} records cannot be merged; delete without merge_into.',
      );
    }
    if (into == op.id) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'merge_into: a record cannot be merged into itself.',
      );
    }
    final survivor = _rows[op.entity]?[into];
    if (survivor == null) {
      return PlanBlock(
        BlockReason.unknownReference,
        'merge_into: no ${entry.name} record has id $into.',
      );
    }
    if (entry.parent case final parent?
        when survivor.parentId != row.parentId) {
      return PlanBlock(
        BlockReason.invalidValue,
        'merge_into: $into belongs to another ${parent.entity} record; a '
        '${entry.name} record merges only into one beside it.',
      );
    }
    if (survivor.ownerId != row.ownerId) {
      return PlanBlock(
        BlockReason.otherProfileReference,
        'merge_into: $into belongs to another diver profile.',
      );
    }
    if (_deleted.contains((op.entity, into))) {
      return PlanBlock(
        BlockReason.referenceDeleted,
        'merge_into: this change set deletes or merges $into too.',
      );
    }
    if (_linksChangedElsewhere(op.entity) case final where?) {
      return PlanBlock(
        BlockReason.notPermitted,
        'merge_into: this change set also changes ${entry.name} links on '
        '$where, and which links a merge moves depends on them. Merge in a '
        'change set of its own.',
      );
    }
    return null;
  }

  /// The entity of an update in the set that changes links to [entity]
  /// records, or null when none does.
  String? _linksChangedElsewhere(String entity) {
    for (final op in set.operations) {
      if (op is! UpdateOp) continue;
      final relations = writes.named(op.entity)?.relations ?? const {};
      for (final name in op.relations.keys) {
        if (relations[name]?.refEntity == entity) return op.entity;
      }
    }
    return null;
  }

  /// A block when [op]'s merge changes a field of the survivor that the set
  /// also sets, since the plan works the merge out from the survivor as it
  /// stands.
  PlanBlock? _survivorClash(DeleteOp op, DeleteReach reach) {
    final named = _updatedFields[(op.entity, op.mergeInto!)] ?? const {};
    final both = reach.survivor.keys.where(named.contains).toList();
    if (both.isEmpty) return null;
    return PlanBlock(
      BlockReason.notPermitted,
      'merge_into: the merge changes ${both.join(', ')} on ${op.mergeInto}, '
      'which this change set also sets. Change it in a set of its own.',
    );
  }

  /// What the diver knows the survivor of [op] by, and what the merge
  /// changes on it, listed as indirect field changes.
  Future<({String? title, Map<String, FieldChange> fields})> _survivorView(
    DeleteOp op,
    WritableEntry entry,
    DeleteReach reach,
  ) async {
    final survivor = _rows[op.entity]![op.mergeInto!]!;
    // As an earlier change in the set leaves it, such as a rename, so the
    // confirmation names what the merge goes into. A field the merge changes
    // is never one the set sets too ([_survivorClash]).
    final document = {
      ...await _document(entry, op.mergeInto!, survivor.ownerId),
      ...?_valuesSoFar[(op.entity, op.mergeInto!)],
    };
    return (
      title: entry.titleOf(document),
      fields: {
        for (final MapEntry(:key, :value) in reach.survivor.entries)
          key: FieldChange(document[key], value, indirect: true),
      },
    );
  }
}
