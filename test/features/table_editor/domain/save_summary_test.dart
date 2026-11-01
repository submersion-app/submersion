import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/table_editor/domain/paste_planner.dart';
import 'package:submersion/features/table_editor/domain/save_summary.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';

import '../../../shared/widgets/entity_table/entity_table_test_harness.dart';

/// The summary a diver reads before Save all (#3422).
void main() {
  TableDraft draft(
    String id, {
    Object? original,
    Object? value = 'x',
    TableDraftFlag? flag,
  }) => TableDraft(
    entityId: id,
    fieldName: 'f',
    original: original,
    value: value,
    flag: flag,
  );

  test(
    'counts saveable, flagged, overwriting and changed-elsewhere drafts',
    () {
      final s = SaveSummary.from([
        draft('a'),
        draft('b', original: 'old'),
        draft('c', flag: TableDraftFlag.unparsable),
        draft('d', original: 'old', flag: TableDraftFlag.changedElsewhere),
      ]);

      expect(s.changed, 2);
      expect(s.needsAttention, 2);
      expect(s.overwrites, 1);
      expect(s.changedElsewhere, 1);
      expect(s.skipped, isEmpty);
      expect(s.matching, isNull);
      expect(s.notes, isEmpty);
    },
  );

  test('the last paste\'s matching and skips pass through with the notes', () {
    const paste = PastePlan<TestField>(
      matching: PasteMatching.byNumber,
      hadHeader: true,
      cells: const [],
      skipped: const [PasteSkip(PasteSkipReason.hiddenRow, detail: '9')],
    );

    final s = SaveSummary.from(
      [draft('a')],
      lastPaste: paste,
      notes: const ['note'],
    );

    expect(s.matching, PasteMatching.byNumber);
    expect(s.skipped.single.detail, '9');
    expect(s.notes, ['note']);
  });
}
