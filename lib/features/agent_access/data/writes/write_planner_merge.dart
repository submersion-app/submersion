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
    return null;
  }

  /// What the diver knows the survivor of [op] by.
  Future<String?> _mergeTitle(DeleteOp op, WritableEntry entry) async {
    final survivor = _rows[op.entity]![op.mergeInto!]!;
    return entry.titleOf(
      await _document(entry, op.mergeInto!, survivor.ownerId),
    );
  }
}
