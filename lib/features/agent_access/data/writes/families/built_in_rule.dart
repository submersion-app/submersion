import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

/// A block when [check] changes a built-in record, one the app ships, in a
/// way its settings page does not allow: an update naming anything beyond
/// [allowed], or any delete. [what] names the records, as "dive types".
PlanBlock? builtInBlock(
  WriteCheck check,
  String what, {
  Set<String> allowed = const {},
}) {
  if (check.document?['is_built_in'] != true) return null;
  if (check.kind == ChangeKind.update &&
      check.values.keys.every(allowed.contains)) {
    return null;
  }
  final rule = allowed.isEmpty
      ? 'which the app does not let a diver change or delete'
      : 'of which a diver may change only ${allowed.join(' and ')}';
  return PlanBlock(
    BlockReason.notPermitted,
    'This is one of the app\'s built-in $what, $rule.',
  );
}

/// A block for a create naming sort_order 0, which the repository reads as
/// "after the last" and stores as the next free slot, so the plan would list
/// a value that is never stored.
PlanBlock? appendSlotBlock(WriteCheck check) =>
    check.kind == ChangeKind.create && check.values['sort_order'] == 0
    ? const PlanBlock(
        BlockReason.invalidValue,
        'sort_order: a new record given 0 goes after the last one. Leave '
        'sort_order out to put it last, or give a slot from 1.',
      )
    : null;

/// A block for a delete the settings page refuses while a dive uses the
/// record, which [inUse] answers as the page asks it.
Future<PlanBlock?> inUseBlock(
  WriteCheck check,
  String what,
  Future<bool> Function(String id) inUse,
) async {
  if (check.kind != ChangeKind.delete || !await inUse(check.id!)) return null;
  return PlanBlock(
    BlockReason.notPermitted,
    'A dive uses this $what, and the app does not delete one in use. Take it '
    'off those dives first.',
  );
}

/// How many rows of [table] hold [id] in [column], leaving out the rows whose
/// [except] column holds one of its values.
Future<int> countLinks(
  String table,
  String column,
  String id, {
  (String, List<String>)? except,
}) async {
  final (skipColumn, skip) = except ?? ('', const <String>[]);
  final notIn = skip.isEmpty
      ? ''
      : ' AND "$skipColumn" NOT IN (${List.filled(skip.length, '?').join(', ')})';
  return (await DatabaseService.instance.database
          .customSelect(
            'SELECT COUNT(*) AS n FROM "$table" WHERE "$column" = ?$notIn',
            variables: [
              Variable.withString(id),
              for (final value in skip) Variable.withString(value),
            ],
          )
          .getSingle())
      .read<int>('n');
}
