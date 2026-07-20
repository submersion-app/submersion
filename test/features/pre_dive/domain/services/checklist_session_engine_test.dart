import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/services/checklist_session_engine.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveSession session({
    bool strict = false,
    PreDiveSessionStatus status = PreDiveSessionStatus.inProgress,
  }) => PreDiveSession(
    id: 's1',
    templateName: 'T',
    strictOrder: strict,
    startedAt: now,
    status: status,
    createdAt: now,
    updatedAt: now,
  );

  PreDiveSessionItem item(
    int order, {
    PreDiveItemState state = PreDiveItemState.pending,
    bool required = false,
  }) => PreDiveSessionItem(
    id: 'i$order',
    sessionId: 's1',
    title: 'Item $order',
    sortOrder: order,
    state: state,
    isRequired: required,
    createdAt: now,
    updatedAt: now,
  );

  group('nextActionableItem / isItemActionable', () {
    test('free order: every pending item is actionable', () {
      final items = [item(0, state: PreDiveItemState.done), item(1), item(2)];
      final s = session();
      expect(
        ChecklistSessionEngine.isItemActionable(s, items, items[1]),
        isTrue,
      );
      expect(
        ChecklistSessionEngine.isItemActionable(s, items, items[2]),
        isTrue,
      );
      expect(
        ChecklistSessionEngine.isItemActionable(s, items, items[0]),
        isFalse,
      );
    });

    test('strict order: only the first pending item is actionable', () {
      final items = [item(0, state: PreDiveItemState.done), item(1), item(2)];
      final s = session(strict: true);
      expect(ChecklistSessionEngine.nextActionableItem(s, items)!.id, 'i1');
      expect(
        ChecklistSessionEngine.isItemActionable(s, items, items[1]),
        isTrue,
      );
      expect(
        ChecklistSessionEngine.isItemActionable(s, items, items[2]),
        isFalse,
      );
    });

    test('locked session: nothing is actionable', () {
      final items = [item(0)];
      final s = session(status: PreDiveSessionStatus.completed);
      expect(
        ChecklistSessionEngine.isItemActionable(s, items, items[0]),
        isFalse,
      );
      expect(ChecklistSessionEngine.nextActionableItem(s, items), isNull);
    });
  });

  group('canComplete', () {
    test('truth table over required/optional and states', () {
      // required pending -> false
      expect(
        ChecklistSessionEngine.canComplete([item(0, required: true)]),
        isFalse,
      );
      // required skipped -> false (skip is not a valid required outcome)
      expect(
        ChecklistSessionEngine.canComplete([
          item(0, required: true, state: PreDiveItemState.skipped),
        ]),
        isFalse,
      );
      // required done -> true
      expect(
        ChecklistSessionEngine.canComplete([
          item(0, required: true, state: PreDiveItemState.done),
        ]),
        isTrue,
      );
      // required flagged -> true (informed decision, confirmed in UI)
      expect(
        ChecklistSessionEngine.canComplete([
          item(0, required: true, state: PreDiveItemState.flagged),
        ]),
        isTrue,
      );
      // optional pending does not block
      expect(
        ChecklistSessionEngine.canComplete([
          item(0),
          item(1, required: true, state: PreDiveItemState.done),
        ]),
        isTrue,
      );
      // empty list completes
      expect(ChecklistSessionEngine.canComplete(const []), isTrue);
    });
  });

  test('flaggedCount and resolvedCount', () {
    final items = [
      item(0, state: PreDiveItemState.flagged),
      item(1, state: PreDiveItemState.done),
      item(2),
    ];
    expect(ChecklistSessionEngine.flaggedCount(items), 1);
    expect(ChecklistSessionEngine.resolvedCount(items), 2);
  });
}
