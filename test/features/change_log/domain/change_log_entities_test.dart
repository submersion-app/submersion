import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_revert_plan.dart';

void main() {
  final event = ChangeLogEvent(
    id: 1,
    operationId: 'op',
    table: 'dives',
    recordId: 'dive',
    action: ChangeLogAction.insert,
    changedAt: DateTime(2026),
    schemaVersion: 332,
  );

  test('a logged value can be copied to null', () {
    const change = ChangeLogFieldChange(
      table: 'dives',
      column: 'notes',
      oldValue: 'Calm',
      newValue: 'Rough',
    );

    final cleared = change.copyWith(oldValue: null);

    expect(cleared.oldValue, isNull);
    expect(cleared.newValue, 'Rough');
    expect(change.copyWith(), change);
  });

  test('a revert item copies with a block and can lose it', () {
    final item = ChangeLogRevertItem(event: event, changedSince: true);

    final blocked = item.copyWith(block: ChangeLogBlock.inUse);

    expect(blocked.block, ChangeLogBlock.inUse);
    expect(blocked.changedSince, isTrue);
    expect(blocked.copyWith(block: null).block, isNull);
    expect(item.copyWith(), item);
  });

  test('a plan, a result, a preview and a cursor copy', () {
    final item = ChangeLogRevertItem(event: event);
    final plan = ChangeLogRevertPlan(operationId: 'op', items: [item]);
    const result = ChangeLogRevertResult(reverted: 1, kept: 0);
    const preview = ChangeLogPreview(fields: [], total: 2);
    const cursor = ChangeLogPageCursor(lastEventId: 5, id: 'a');

    expect(plan.copyWith(wholeOperation: true).wholeOperation, isTrue);
    expect(result.copyWith(kept: 2).kept, 2);
    expect(
      result
          .copyWith(operationId: 'op')
          .copyWith(operationId: null)
          .operationId,
      isNull,
    );
    expect(preview.copyWith(total: 3).total, 3);
    expect(
      preview
          .copyWith(rootAction: ChangeLogAction.insert)
          .copyWith(rootAction: null)
          .rootAction,
      isNull,
    );
    expect(cursor.copyWith(id: 'b').id, 'b');
  });
}
