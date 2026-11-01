import 'package:submersion/features/table_editor/domain/table_draft.dart';

/// Where a committed cell sends the editor next (#3422).
enum CellMove { none, down, next, previous }

/// The next editable position, or null at the sheet's edge or when [from]
/// is not on the sheet. Enter is [CellMove.down]: the same column, one row
/// on. Tab is [CellMove.next]: the next editable column, wrapping to the
/// next row's first; Shift+Tab the reverse.
CellPosition? nextCell({
  required CellPosition from,
  required CellMove move,
  required List<String> rowIds,
  required List<String> editableFieldNames,
}) {
  final row = rowIds.indexOf(from.entityId);
  final column = editableFieldNames.indexOf(from.fieldName);
  if (row < 0 || column < 0) return null;
  switch (move) {
    case CellMove.none:
      return null;
    case CellMove.down:
      if (row + 1 >= rowIds.length) return null;
      return CellPosition(rowIds[row + 1], from.fieldName);
    case CellMove.next:
      if (column + 1 < editableFieldNames.length) {
        return CellPosition(from.entityId, editableFieldNames[column + 1]);
      }
      if (row + 1 >= rowIds.length) return null;
      return CellPosition(rowIds[row + 1], editableFieldNames.first);
    case CellMove.previous:
      if (column > 0) {
        return CellPosition(from.entityId, editableFieldNames[column - 1]);
      }
      if (row == 0) return null;
      return CellPosition(rowIds[row - 1], editableFieldNames.last);
  }
}
