import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/record_editing/editor_row_merge.dart';

typedef _Row = ({String id, String text});

_Row _r(String id, String text) => (id: id, text: text);

List<_Row> _merge({
  required List<_Row> form,
  required List<_Row>? start,
  required List<_Row> stored,
}) => mergeEditorRows<_Row, _Row>(
  formRows: form,
  formDrafts: form,
  startDrafts: start,
  storedRows: stored,
  rowId: (row) => row.id,
  draftId: (draft) => draft.id,
);

void main() {
  test('a new record writes every form row as the form has it', () {
    expect(
      _merge(form: [_r('a', 'x'), _r('b', 'y')], start: null, stored: []),
      [_r('a', 'x'), _r('b', 'y')],
    );
  });

  test('a row left alone follows its stored copy', () {
    expect(
      _merge(
        form: [_r('a', 'x')],
        start: [_r('a', 'x')],
        stored: [_r('a', 'y')],
      ),
      [_r('a', 'y')],
    );
  });

  test('a row left alone that was removed elsewhere is dropped', () {
    expect(
      _merge(
        form: [_r('a', 'x'), _r('b', 'z')],
        start: [_r('a', 'x'), _r('b', 'y')],
        stored: [_r('b', 'y')],
      ),
      [_r('b', 'z')],
    );
  });

  test('a changed row is written as the form has it', () {
    expect(
      _merge(
        form: [_r('a', 'z')],
        start: [_r('a', 'x')],
        stored: [_r('a', 'y')],
      ),
      [_r('a', 'z')],
    );
  });

  test('a row added on the form is written', () {
    expect(
      _merge(
        form: [_r('a', 'x'), _r('n', 'new')],
        start: [_r('a', 'x')],
        stored: [_r('a', 'x')],
      ),
      [_r('a', 'x'), _r('n', 'new')],
    );
  });

  test('a row the diver removed is not written, even if changed elsewhere', () {
    expect(
      _merge(
        form: [_r('a', 'x')],
        start: [_r('a', 'x'), _r('b', 'y')],
        stored: [_r('a', 'x'), _r('b', 'synced')],
      ),
      [_r('a', 'x')],
    );
  });

  test('a row added elsewhere is kept after the form rows', () {
    expect(
      _merge(
        form: [_r('a', 'z')],
        start: [_r('a', 'x')],
        stored: [_r('c', 'elsewhere'), _r('a', 'x')],
      ),
      [_r('a', 'z'), _r('c', 'elsewhere')],
    );
  });

  test('rows keep the form order, stored-only rows after them', () {
    expect(
      _merge(
        form: [_r('b', 'b'), _r('a', 'a')],
        start: [_r('a', 'a'), _r('b', 'b')],
        stored: [_r('a', 'a'), _r('c', 'c'), _r('b', 'b')],
      ),
      [_r('b', 'b'), _r('a', 'a'), _r('c', 'c')],
    );
  });
}
