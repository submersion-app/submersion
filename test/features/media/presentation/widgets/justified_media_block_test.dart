import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_block.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_grid.dart';

JustifiedMediaTable _squares(int count) => JustifiedMediaTable.build(
  sections: [
    JustifiedSection(headerExtents: const [], ratios: List.filled(count, 1.0)),
  ],
  paneWidth: 316,
  targetHeight: 100,
  gap: 4,
  inset: 0,
);

Future<List<JustifiedBlockCell>> _pump(
  WidgetTester tester,
  List<double> ratios, {
  double width = 616,
  int? maxRows,
  int keepAtLeast = 0,
  TextDirection direction = TextDirection.ltr,
}) async {
  final cells = <JustifiedBlockCell>[];
  await tester.pumpWidget(
    Directionality(
      textDirection: direction,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: JustifiedMediaBlock(
            ratios: ratios,
            rowHeight: 150,
            gap: 4,
            maxRows: maxRows,
            keepAtLeast: keepAtLeast,
            cellBuilder: (context, cell) {
              cells.add(cell);
              return SizedBox.expand(key: ValueKey('cell-${cell.index}'));
            },
          ),
        ),
      ),
    ),
  );
  return cells;
}

/// Counts how often a tile's state is created, to tell a kept tile from a
/// rebuilt one.
class _Counted extends StatefulWidget {
  const _Counted({super.key, required this.created});

  final List<Key?> created;

  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  void initState() {
    super.initState();
    widget.created.add(widget.key);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

Rect _rect(WidgetTester tester, int index) =>
    tester.getRect(find.byKey(ValueKey('cell-$index')));

void main() {
  group('justifiedVisibleCount', () {
    // 316 wide at 100 tall with a 4 px gap holds three squares a row.
    final table = _squares(12);

    test('keeps whole rows up to maxRows', () {
      expect(justifiedVisibleCount(table, maxRows: 3), 9);
    });

    test('keeps everything with no cap', () {
      expect(justifiedVisibleCount(table), 12);
    });

    test('keeps everything when the cap is above the row count', () {
      expect(justifiedVisibleCount(table, maxRows: 5), 12);
    });

    test('grows to the row holding the last item it must keep', () {
      expect(justifiedVisibleCount(table, maxRows: 3, keepAtLeast: 11), 12);
      expect(justifiedVisibleCount(table, maxRows: 1, keepAtLeast: 4), 6);
    });
  });

  testWidgets('lays tiles out at their own shapes in a flush row', (
    tester,
  ) async {
    // 225 + 225 + 150 + gaps fits 616; the fourth photo closes the row,
    // which then stretches to end at the pane edge.
    await _pump(tester, [1.5, 1.5, 1.0, 1.5]);

    final a = _rect(tester, 0);
    final b = _rect(tester, 1);
    final c = _rect(tester, 2);
    expect(a.height, b.height);
    expect(a.height, c.height);
    expect(a.width, closeTo(b.width, 0.01));
    expect(c.width, closeTo(a.width * 2 / 3, 1));
    expect(c.right, closeTo(616, 0.01));
    expect(_rect(tester, 3).top, closeTo(a.bottom + 4, 0.01));
  });

  testWidgets('a lone photo keeps the row height and is not stretched', (
    tester,
  ) async {
    final cells = await _pump(tester, [1.5]);

    expect(_rect(tester, 0).size, const Size(225, 150));
    expect(cells.single.hiddenCount, 0);
    expect(tester.getSize(find.byType(JustifiedMediaBlock)).height, 150);
  });

  testWidgets('stops at maxRows and tells the last tile what was cut', (
    tester,
  ) async {
    // 316 wide at 150 tall holds two squares a row.
    final cells = await _pump(
      tester,
      List.filled(9, 1.0),
      width: 316,
      maxRows: 3,
    );

    expect(cells.map((c) => c.index), List.generate(6, (i) => i));
    expect(cells.last.hiddenCount, 3);
    expect(cells.take(5).every((c) => c.hiddenCount == 0), isTrue);
    expect(
      tester.getSize(find.byType(JustifiedMediaBlock)).height,
      closeTo(_rect(tester, 5).bottom - _rect(tester, 0).top, 0.01),
    );
  });

  testWidgets('a cap the items fit within cuts nothing', (tester) async {
    final cells = await _pump(
      tester,
      List.filled(6, 1.0),
      width: 316,
      maxRows: 3,
    );

    expect(cells, hasLength(6));
    expect(cells.every((c) => c.hiddenCount == 0), isTrue);
  });

  testWidgets('no items build nothing', (tester) async {
    final cells = await _pump(tester, const []);

    expect(cells, isEmpty);
    expect(tester.getSize(find.byType(JustifiedMediaBlock)).height, 0);
  });

  test('rejects a cap of no rows', () {
    expect(
      () => JustifiedMediaBlock(
        ratios: const [1.0],
        rowHeight: 150,
        gap: 4,
        maxRows: 0,
        cellBuilder: (_, _) => const SizedBox(),
      ),
      throwsAssertionError,
    );
  });

  testWidgets('lays rows out from the right in a right-to-left language', (
    tester,
  ) async {
    await _pump(tester, [1.5, 1.0], direction: TextDirection.rtl);

    // An open row keeps its shapes; in RTL it starts at the right edge.
    expect(_rect(tester, 0).right, closeTo(616, 0.01));
    expect(_rect(tester, 1).right, closeTo(_rect(tester, 0).left - 4, 0.01));
  });

  testWidgets('a keyed tile keeps its state when the order shifts', (
    tester,
  ) async {
    final created = <Key?>[];
    Future<void> pumpIds(List<String> ids) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 616,
            child: JustifiedMediaBlock(
              ratios: List.filled(ids.length, 1.0),
              rowHeight: 150,
              gap: 4,
              cellBuilder: (context, cell) =>
                  _Counted(key: ValueKey(ids[cell.index]), created: created),
            ),
          ),
        ),
      ),
    );

    await pumpIds(['a', 'b', 'c']);
    expect(created, hasLength(3));

    // A new photo arrives first: the three already shown keep their state.
    await pumpIds(['new', 'a', 'b', 'c']);

    expect(created, hasLength(4));
    expect(created.last, const ValueKey('new'));
  });
}
