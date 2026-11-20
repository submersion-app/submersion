import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/presentation/helpers/justified_preview_layout.dart';

/// The fixed-size justified preview on detail cards (issue #4741): a few
/// rows of a longer list, with a count of what they leave out.
void main() {
  JustifiedPreviewLayout layout(
    List<double> ratios, {
    double width = 400,
    double rowHeight = 100,
    double gap = 4,
    int? maxRows,
    int? totalCount,
  }) => layoutJustifiedPreview(
    ratios: ratios,
    width: width,
    rowHeight: rowHeight,
    gap: gap,
    maxRows: maxRows,
    totalCount: totalCount,
  );

  test('lays out every item when no row limit is given', () {
    final result = layout(List.filled(9, 1.0));
    expect(result.shownCount, 9);
    expect(result.hiddenCount, 0);
    expect(result.rects, hasLength(9));
  });

  test('stops after maxRows rows and counts the rest as hidden', () {
    // 400 wide at 100 high: four squares a row (4 * 100 + 3 * 4 = 412,
    // closest to the target with four).
    final result = layout(List.filled(20, 1.0), maxRows: 2);
    expect(result.shownCount, 8);
    expect(result.hiddenCount, 12);
    final tops = {for (final r in result.rects) r.top};
    expect(tops, hasLength(2));
  });

  test('the rows it keeps end flush with the pane edge', () {
    final result = layout([
      1.5,
      0.75,
      1.0,
      1.33,
      1.5,
      0.75,
      1.0,
      1.33,
      1.5,
      0.75,
    ], maxRows: 2);
    for (final top in {for (final r in result.rects) r.top}) {
      final row = [
        for (final r in result.rects)
          if (r.top == top) r,
      ];
      expect(row.last.right, closeTo(400, 0.01));
      expect(row.first.left, 0);
    }
  });

  test('the height covers the rows shown and one gap between them', () {
    final result = layout(List.filled(20, 1.0), maxRows: 2);
    final bottom = result.rects
        .map((r) => r.bottom)
        .reduce((a, b) => a > b ? a : b);
    expect(result.height, closeTo(bottom, 0.001));
    final rowHeights = {for (final r in result.rects) r.height};
    expect(rowHeights, hasLength(1));
    expect(result.height, closeTo(2 * rowHeights.single + 4, 0.001));
  });

  test('items known to exist beyond the list count as hidden', () {
    // A capped read: 5 items in hand of 30, all of them shown.
    final result = layout(List.filled(5, 1.0), totalCount: 30, maxRows: 2);
    expect(result.shownCount, 5);
    expect(result.hiddenCount, 25);
  });

  test('a list that fits in the rows hides nothing', () {
    final result = layout(List.filled(3, 1.0), maxRows: 2);
    expect(result.shownCount, 3);
    expect(result.hiddenCount, 0);
    // A lone last row keeps the target height rather than stretching.
    expect(result.rects.first.height, 100);
  });

  test('nothing to lay out, or no room, gives an empty layout', () {
    expect(layout(const []).rects, isEmpty);
    expect(layout(const []).height, 0);
    final noRoom = layout(List.filled(4, 1.0), width: 0, totalCount: 4);
    expect(noRoom.rects, isEmpty);
    expect(noRoom.hiddenCount, 4);
  });
}
