import 'package:equatable/equatable.dart';

import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';

/// Why part of a revert cannot happen.
enum ChangeLogBlock {
  /// The record the change was made to no longer exists.
  recordGone,

  /// A later migration dropped the column.
  columnGone,

  /// A later migration rewrote the column, so the old value means something
  /// else now.
  rewritten,

  /// The record a restored row belongs to no longer exists.
  parentGone,

  /// A deleted record is already back.
  alreadyRestored,

  /// Later data still uses a record the entry created.
  inUse,
}

/// One thing a revert would do: put a column back, or with no [column], bring
/// back a deleted record or remove a created one.
class ChangeLogRevertItem extends Equatable {
  const ChangeLogRevertItem({
    required this.event,
    this.column,
    this.logged,
    this.target,
    this.current,
    this.block,
    this.changedSince = false,
  });

  final ChangeLogEvent event;
  final String? column;

  /// What the entry set the column to.
  final Object? logged;

  /// What a revert would put back.
  final Object? target;

  /// What the column holds now.
  final Object? current;

  final ChangeLogBlock? block;

  /// The record no longer stands as the entry left it, so a revert would
  /// overwrite something later.
  final bool changedSince;

  bool get isBlocked => block != null;

  /// Brings back a record the entry deleted.
  bool get restoresRecord =>
      column == null && event.action == ChangeLogAction.delete;

  /// Removes a record the entry created.
  bool get removesRecord =>
      column == null && event.action == ChangeLogAction.insert;

  @override
  List<Object?> get props => [
    event,
    column,
    logged,
    target,
    current,
    block,
    changedSince,
  ];
}

/// What a revert would do, worked out before anything is written.
class ChangeLogRevertPlan extends Equatable {
  const ChangeLogRevertPlan({
    required this.operationId,
    required this.items,
    this.wholeOperation = false,
  });

  final String operationId;
  final List<ChangeLogRevertItem> items;

  /// Whether this covers the whole entry, so the entry can show as reverted.
  final bool wholeOperation;

  bool get hasChangedSince =>
      items.any((item) => item.changedSince && !item.isBlocked);

  int get changedSinceCount => items
      .where((item) => item.changedSince && !item.isBlocked)
      .map((item) => item.event.root)
      .toSet()
      .length;

  @override
  List<Object?> get props => [operationId, items, wholeOperation];
}

/// What a revert did.
class ChangeLogRevertResult extends Equatable {
  const ChangeLogRevertResult({
    required this.reverted,
    required this.kept,
    this.keptItems = const [],
    this.operationId,
  });

  final int reverted;
  final int kept;

  /// Each item left alone, with its reason.
  final List<ChangeLogRevertItem> keptItems;

  /// The revert's own entry, when it did anything.
  final String? operationId;

  @override
  List<Object?> get props => [reverted, kept, keptItems, operationId];
}
