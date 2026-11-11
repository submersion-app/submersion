import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_heat_map.dart';

/// The highlighted compartment row's outline frames the row from outside,
/// so every cell in the row stays fully visible under it.
void main() {
  const cellHeight = 9.0;
  const width = 300.0;
  const stroke = TissueHeatMapStrip.rowOutlineStrokeWidth;

  Rect rowRect(int index) => const Rect.fromLTWH(
    0,
    0,
    width,
    cellHeight,
  ).shift(Offset(0, index * cellHeight));

  test('the stroke lies entirely outside the row', () {
    final outline = TissueHeatMapStrip.rowOutlineRect(
      index: 4,
      cellHeight: cellHeight,
      width: width,
    );
    final row = rowRect(4);
    // A stroke centred on [outline] spans stroke/2 either side of its edges;
    // its inner edge must not reach into the row.
    expect(outline.top + stroke / 2, lessThanOrEqualTo(row.top));
    expect(outline.bottom - stroke / 2, greaterThanOrEqualTo(row.bottom));
  });

  test('it still hugs the row, no more than one stroke away', () {
    final outline = TissueHeatMapStrip.rowOutlineRect(
      index: 4,
      cellHeight: cellHeight,
      width: width,
    );
    final row = rowRect(4);
    expect(row.top - outline.top, closeTo(stroke / 2, 1e-9));
    expect(outline.bottom - row.bottom, closeTo(stroke / 2, 1e-9));
  });
}
