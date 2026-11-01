import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_draft_state.dart';

/// Drafts are the table editor's pending edits (#3422): kept per entity and
/// field until Save all, dropped when they equal what is stored.
void main() {
  TableDraft draft({
    String entityId = 'd1',
    String fieldName = 'visibility',
    Object? original = 10.0,
    Object? value = 12.0,
    TableDraftFlag? flag,
    String? rawText,
  }) => TableDraft(
    entityId: entityId,
    fieldName: fieldName,
    original: original,
    value: value,
    flag: flag,
    rawText: rawText,
  );

  test('put stores a draft and count follows', () {
    final n = TableDraftsNotifier();
    n.put(draft());
    n.put(draft(entityId: 'd2'));

    expect(n.state.count, 2);
    expect(n.state.at('d1', 'visibility')?.value, 12.0);
    expect(n.state.forEntity('d2'), hasLength(1));
    expect(n.state.isEmpty, isFalse);
  });

  test('put with value equal to original removes any existing draft', () {
    final n = TableDraftsNotifier();
    n.put(draft());
    n.put(draft(value: 10.0));

    expect(n.state.count, 0);
    expect(n.state.at('d1', 'visibility'), isNull);
  });

  test('put keeps a flagged draft even when value equals original', () {
    final n = TableDraftsNotifier();
    n.put(draft(value: 10.0, flag: TableDraftFlag.unparsable, rawText: 'x'));

    expect(n.state.count, 1);
    expect(n.state.flaggedCount, 1);
    expect(n.state.at('d1', 'visibility')?.isSaveable, isFalse);
  });

  test(
    'overwrites is false for null, empty string and empty list originals',
    () {
      expect(draft(original: null).overwrites, isFalse);
      expect(draft(original: '').overwrites, isFalse);
      expect(draft(original: const <String>[]).overwrites, isFalse);
      expect(draft(original: 10.0).overwrites, isTrue);
      expect(draft(original: 'salt').overwrites, isTrue);
    },
  );

  test(
    'rebase keeps the value, replaces original and clears changedElsewhere',
    () {
      final n = TableDraftsNotifier();
      n.put(draft());
      n.flag('d1', 'visibility', TableDraftFlag.changedElsewhere);
      expect(n.state.flaggedCount, 1);

      n.rebase('d1', 'visibility', 11.0);

      final d = n.state.at('d1', 'visibility')!;
      expect(d.value, 12.0);
      expect(d.original, 11.0);
      expect(d.flag, isNull);
      expect(n.state.flaggedCount, 0);
    },
  );

  test('saveable excludes flagged drafts', () {
    final n = TableDraftsNotifier();
    n.put(draft());
    n.put(draft(entityId: 'd2', flag: TableDraftFlag.unknownValue));

    expect(n.state.saveable.map((d) => d.entityId), ['d1']);
    expect(n.state.all, hasLength(2));
  });

  test('list values compare by content', () {
    final n = TableDraftsNotifier();
    n.put(draft(original: ['a', 'b'], value: ['a', 'b']));

    expect(n.state.count, 0);
  });

  test('remove and clear drop drafts; editing and selected are tracked', () {
    final n = TableDraftsNotifier();
    n.put(draft());
    n.put(draft(fieldName: 'notes', original: '', value: 'hi'));
    n.remove('d1', 'notes');
    expect(n.state.count, 1);

    n.setEditing(const CellPosition('d1', 'notes'));
    n.setSelected(const CellPosition('d1', 'visibility'));
    expect(n.state.editing, const CellPosition('d1', 'notes'));
    expect(n.state.selected, const CellPosition('d1', 'visibility'));

    n.clear();
    expect(n.state.isEmpty, isTrue);
    expect(n.state.editing, isNull);
  });
}
