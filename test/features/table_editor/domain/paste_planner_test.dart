import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/table_editor/domain/paste_parser.dart';
import 'package:submersion/features/table_editor/domain/paste_planner.dart';

import '../../../shared/widgets/entity_table/entity_table_test_harness.dart';

/// Where a pasted block lands (#3422): by dive number or name when the
/// block carries one, by position otherwise, never on a hidden row.
void main() {
  // A sheet of dives numbered 1 to 20, as most logbooks start.
  final rows = [for (var n = 1; n <= 20; n++) SheetRow(id: 'd$n', number: n)];
  const columns = [TestField.entityName, TestField.entityCount];

  PastePlan<TestField> plan(
    String text, {
    int selectedRow = 0,
    int selectedColumn = 1,
    List<SheetRow>? sheet,
    Set<String> hidden = const {},
    bool Function(TestField)? editable,
  }) => planPaste<TestField>(
    block: parsePasteText(text),
    rows: sheet ?? rows,
    selectedRowIndex: selectedRow,
    visibleColumns: columns,
    selectedColumnIndex: selectedColumn,
    isEditableColumn: editable ?? (_) => true,
    columnFromLabel: (h) => switch (h.toLowerCase()) {
      'name' => TestField.entityName,
      'count' => TestField.entityCount,
      _ => null,
    },
    isKeyHeader: (h) => h.toLowerCase() == 'dive',
    hiddenKeys: hidden,
  );

  test('single integer column is positional', () {
    final p = plan('6\n8\n7', selectedRow: 2);

    expect(p.matching, PasteMatching.byPosition);
    expect(p.cells.map((c) => (c.entityId, c.field, c.text)), [
      ('d3', TestField.entityCount, '6'),
      ('d4', TestField.entityCount, '8'),
      ('d5', TestField.entityCount, '7'),
    ]);
    expect(p.skipped, isEmpty);
  });

  test('two columns with every first value a dive number match by number', () {
    final p = plan('12\t6\n3\t8');

    expect(p.matching, PasteMatching.byNumber);
    expect(p.hadHeader, isFalse);
    expect(p.cells.map((c) => (c.entityId, c.text)), [
      ('d12', '6'),
      ('d3', '8'),
    ]);
  });

  test('a header naming the key column matches by number even with one column '
      'of data', () {
    final p = plan('Dive\tCount\n4\t9');

    expect(p.matching, PasteMatching.byNumber);
    expect(p.hadHeader, isTrue);
    expect(p.cells.single.entityId, 'd4');
    expect(p.cells.single.field, TestField.entityCount);
  });

  test('a hidden dive number is skipped as hiddenRow, an unknown one as '
      'unknownRow', () {
    final p = plan('2\t6\n99\t7\n5\t8', hidden: {'99'});

    expect(p.matching, PasteMatching.byNumber);
    expect(p.cells.map((c) => c.entityId), ['d2', 'd5']);
    expect(p.skipped.map((s) => (s.reason, s.detail)), [
      (PasteSkipReason.hiddenRow, '99'),
    ]);
  });

  test('under a key header, a number that is neither on the sheet nor hidden '
      'is unknownRow', () {
    final p = plan('Dive\tCount\n2\t6\n42\t7');

    expect(p.matching, PasteMatching.byNumber);
    expect(p.skipped.single.reason, PasteSkipReason.unknownRow);
    expect(p.skipped.single.detail, '42');
  });

  test('without a header, a first column with a number no dive has is '
      'positional', () {
    final p = plan('2\t6\n42\t7', selectedColumn: 0);

    expect(p.matching, PasteMatching.byPosition);
    expect(p.skipped, isEmpty);
    expect(p.cells.map((c) => c.text), ['2', '6', '42', '7']);
  });

  test('a first column that is not all numbers falls back to position', () {
    final p = plan('2\t6\nx\t7');

    expect(p.matching, PasteMatching.byPosition);
  });

  test('read-only columns are skipped and reported once each', () {
    final p = plan(
      'a\tb\nc\td',
      selectedColumn: 0,
      editable: (f) => f == TestField.entityName,
    );

    expect(p.cells.map((c) => (c.entityId, c.field, c.text)), [
      ('d1', TestField.entityName, 'a'),
      ('d2', TestField.entityName, 'c'),
    ]);
    expect(p.skipped.map((s) => (s.reason, s.detail)), [
      (PasteSkipReason.readOnlyColumn, TestField.entityCount.name),
    ]);
  });

  test('rows beyond the sheet are reported as truncated', () {
    final p = plan('1\n2\n3\n4', selectedRow: 18);

    expect(p.cells.map((c) => c.entityId), ['d19', 'd20']);
    expect(p.skipped.single.reason, PasteSkipReason.truncated);
    expect(p.skipped.single.count, 2);
  });

  test('columns beyond the sheet are reported as truncated too', () {
    final p = plan('a\tb\tc', selectedColumn: 1);

    expect(p.cells.map((c) => c.field), [TestField.entityCount]);
    expect(p.skipped.single.reason, PasteSkipReason.truncated);
  });

  test('unknown header is dropped and reported', () {
    final p = plan('Dive\tCount\tBogus\n4\t9\tz');

    expect(p.cells.map((c) => (c.field, c.text)), [
      (TestField.entityCount, '9'),
    ]);
    expect(p.skipped.map((s) => (s.reason, s.detail)), [
      (PasteSkipReason.unknownColumn, 'Bogus'),
    ]);
  });

  test(
    'a header without the key column maps columns and fills by position',
    () {
      final p = plan('Count\tName\n9\tx', selectedRow: 4);

      expect(p.matching, PasteMatching.byPosition);
      expect(p.cells.map((c) => (c.entityId, c.field, c.text)), [
        ('d5', TestField.entityCount, '9'),
        ('d5', TestField.entityName, 'x'),
      ]);
    },
  );

  test('names match case-insensitively', () {
    final sheet = [
      const SheetRow(id: 's1', name: 'Blue Hole'),
      const SheetRow(id: 's2', name: 'Reef'),
    ];
    final p = plan('blue hole\t9\nREEF\t8', sheet: sheet);

    expect(p.matching, PasteMatching.byName);
    expect(p.cells.map((c) => c.entityId), ['s1', 's2']);
  });

  test('a single value lands on the selected cell only', () {
    final p = plan('6', selectedRow: 3);

    expect(p.cells.single.entityId, 'd4');
    expect(p.cells.single.field, TestField.entityCount);
  });

  test('a single value on a read-only cell is skipped', () {
    final p = plan('6', editable: (_) => false);

    expect(p.cells, isEmpty);
    expect(p.skipped.single.reason, PasteSkipReason.readOnlyColumn);
  });
}
