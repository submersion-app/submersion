import 'package:submersion/features/table_editor/domain/table_draft.dart';

/// Where a committed cell sends the editor next (#3422).
enum CellMove { none, down, next, previous }

/// The next editable position in the order the sheet shows, or null at the
/// sheet's edge or when [from] is not on the sheet. Enter is
/// [CellMove.down]: the same column, the next row that can take it. Tab is
/// [CellMove.next]: the next editable cell along the row, wrapping to the
/// next row; Shift+Tab the reverse. A cell [isEditable] refuses is skipped,
/// so the editor never opens a read-only cell on the way.
CellPosition? nextCell({
  required CellPosition from,
  required CellMove move,
  required List<String> rowIds,
  required List<String> fieldNames,
  required bool Function(String rowId, String fieldName) isEditable,
}) {
  final row = rowIds.indexOf(from.entityId);
  final column = fieldNames.indexOf(from.fieldName);
  if (row < 0 || column < 0) return null;
  switch (move) {
    case CellMove.none:
      return null;
    case CellMove.down:
      for (var r = row + 1; r < rowIds.length; r++) {
        if (isEditable(rowIds[r], from.fieldName)) {
          return CellPosition(rowIds[r], from.fieldName);
        }
      }
      return null;
    case CellMove.next:
      var r = row;
      var c = column + 1;
      while (r < rowIds.length) {
        if (c >= fieldNames.length) {
          r++;
          c = 0;
          continue;
        }
        if (isEditable(rowIds[r], fieldNames[c])) {
          return CellPosition(rowIds[r], fieldNames[c]);
        }
        c++;
      }
      return null;
    case CellMove.previous:
      var r = row;
      var c = column - 1;
      while (r >= 0) {
        if (c < 0) {
          r--;
          c = fieldNames.length - 1;
          continue;
        }
        if (isEditable(rowIds[r], fieldNames[c])) {
          return CellPosition(rowIds[r], fieldNames[c]);
        }
        c--;
      }
      return null;
  }
}
