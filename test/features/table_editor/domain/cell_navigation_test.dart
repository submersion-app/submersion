import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/table_editor/domain/cell_navigation.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';

/// Where Enter, Tab and Shift+Tab take the open cell (#3422).
void main() {
  const rows = ['r1', 'r2', 'r3'];
  const columns = ['a', 'b', 'c'];

  CellPosition? next(CellPosition from, CellMove move) => nextCell(
    from: from,
    move: move,
    rowIds: rows,
    editableFieldNames: columns,
  );

  test('down moves to the same column in the next row and null at the last '
      'row', () {
    expect(
      next(const CellPosition('r1', 'b'), CellMove.down),
      const CellPosition('r2', 'b'),
    );
    expect(next(const CellPosition('r3', 'b'), CellMove.down), isNull);
  });

  test('next moves along the row and wraps to the next row\'s first editable '
      'column', () {
    expect(
      next(const CellPosition('r1', 'a'), CellMove.next),
      const CellPosition('r1', 'b'),
    );
    expect(
      next(const CellPosition('r1', 'c'), CellMove.next),
      const CellPosition('r2', 'a'),
    );
    expect(next(const CellPosition('r3', 'c'), CellMove.next), isNull);
  });

  test('previous from the first editable column wraps to the previous row\'s '
      'last', () {
    expect(
      next(const CellPosition('r2', 'b'), CellMove.previous),
      const CellPosition('r2', 'a'),
    );
    expect(
      next(const CellPosition('r2', 'a'), CellMove.previous),
      const CellPosition('r1', 'c'),
    );
    expect(next(const CellPosition('r1', 'a'), CellMove.previous), isNull);
  });

  test('none stays put, and an unknown cell goes nowhere', () {
    expect(next(const CellPosition('r2', 'b'), CellMove.none), isNull);
    expect(next(const CellPosition('zz', 'b'), CellMove.down), isNull);
    expect(next(const CellPosition('r2', 'zz'), CellMove.next), isNull);
  });
}
