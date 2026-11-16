import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// A card whose content is rows of its own, rather than values of the
/// record, asks the sitting whether it is empty (issue #4527, plan 6).
void main() {
  EditCard<String> card({
    bool Function(EditSession<String> session)? isEmptyInSitting,
    bool Function(EditSession<String> session)? offeredWhenEmpty,
  }) => EditCard<String>(
    id: 'rows',
    title: (_) => 'Rows',
    isEmpty: (record) => record.isEmpty,
    isEmptyInSitting: isEmptyInSitting,
    offeredWhenEmpty: offeredWhenEmpty,
    editorBuilder: (_, _) => const SizedBox.shrink(),
  );

  test('offeredWhenEmpty and isEmptyInSitting default to null', () {
    final plain = card();
    expect(plain.offeredWhenEmpty, isNull);
    expect(plain.isEmptyInSitting, isNull);
    expect(plain.isOfferedWhenEmpty(EditSession<String>('')), isTrue);
  });

  test('a card with isEmptyInSitting is asked it during a sitting, and isEmpty '
      'when locked', () {
    var rows = 0;
    final rowsCard = card(isEmptyInSitting: (_) => rows == 0);
    final session = EditSession<String>('a record');
    addTearDown(session.dispose);

    // Locked: the record decides.
    expect(rowsCard.isEmptyDuring('', null), isTrue);
    expect(rowsCard.isEmptyDuring('a record', null), isFalse);
    // In a sitting: the rows decide, whatever the record holds.
    expect(rowsCard.isEmptyDuring('a record', session), isTrue);
    rows = 1;
    expect(rowsCard.isEmptyDuring('', session), isFalse);
    // A card with no rows of its own asks the record either way.
    expect(card().isEmptyDuring('', session), isTrue);
  });

  test('offeredWhenEmpty is asked of the sitting', () {
    var offered = false;
    final gated = card(offeredWhenEmpty: (_) => offered);
    final session = EditSession<String>('');
    addTearDown(session.dispose);

    expect(gated.isOfferedWhenEmpty(session), isFalse);
    offered = true;
    expect(gated.isOfferedWhenEmpty(session), isTrue);
  });

  group('layoutAnswer', () {
    late RecordEditController<String> controller;
    setUp(() {
      controller = RecordEditController<String>(onSave: (_) async {});
    });
    tearDown(() => controller.dispose());

    test('with no editor open, asks every time', () {
      controller.unlock('');
      var answer = true;
      expect(controller.layoutAnswer('rows', () => answer), isTrue);
      answer = false;
      expect(controller.layoutAnswer('rows', () => answer), isFalse);
    });

    test('while an editor is open, a list card that gained a row keeps the '
        'answer it had', () {
      controller
        ..unlock('')
        ..openCard('notes');
      var empty = true;
      expect(controller.layoutAnswer('rows', () => empty), isTrue);
      empty = false;
      expect(controller.layoutAnswer('rows', () => empty), isTrue);

      // The last editor closed: the page follows the sitting again.
      controller.closeCard('notes');
      expect(controller.layoutAnswer('rows', () => empty), isFalse);

      // A later editor holds what is true when it opens.
      controller.openCard('notes');
      empty = true;
      expect(controller.layoutAnswer('rows', () => empty), isTrue);
    });

    test('a new sitting starts with nothing held', () {
      controller
        ..unlock('')
        ..openCard('notes');
      expect(controller.layoutAnswer('rows', () => true), isTrue);
      controller
        ..lock()
        ..unlock('')
        ..openCard('notes');
      expect(controller.layoutAnswer('rows', () => false), isFalse);
    });
  });
}
