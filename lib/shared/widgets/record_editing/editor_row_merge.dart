/// The rows a Save writes for a list the diver edited on a form, merged
/// onto the list as stored at Save, so a change made elsewhere meanwhile
/// (a sync) to a row the diver left alone is kept (issue #4527, phase 4):
///
/// - a form row whose draft equals its start draft (same id) follows
///   storage: the stored row with that id, or nothing when it was removed
///   elsewhere meanwhile;
/// - a form row the diver changed or added is written as the form has it;
/// - a start row missing from the form (the diver removed it) is not
///   written;
/// - a stored row neither the start nor the form had (added elsewhere
///   meanwhile) is kept, after the form's rows, in stored order.
///
/// With [startDrafts] null (a new record) every form row is written as the
/// form has it. [formRows] and [formDrafts] are parallel lists in the order
/// shown.
List<T> mergeEditorRows<T, R>({
  required List<T> formRows,
  required List<R> formDrafts,
  required List<R>? startDrafts,
  required List<T> storedRows,
  required String Function(T row) rowId,
  required String Function(R draft) draftId,
}) {
  assert(formRows.length == formDrafts.length);
  if (startDrafts == null) return List.of(formRows);
  final startById = {for (final draft in startDrafts) draftId(draft): draft};
  final storedById = {for (final row in storedRows) rowId(row): row};
  final formIds = {for (final row in formRows) rowId(row)};
  return [
    for (var i = 0; i < formRows.length; i++)
      if (startById[draftId(formDrafts[i])] != formDrafts[i])
        formRows[i]
      else
        ?storedById[rowId(formRows[i])],
    for (final row in storedRows)
      if (!startById.containsKey(rowId(row)) && !formIds.contains(rowId(row)))
        row,
  ];
}
