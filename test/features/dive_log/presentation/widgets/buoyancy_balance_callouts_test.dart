import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_balance_callouts.dart';

BalanceCalloutRequest _r(String id, double anchor, double width) =>
    BalanceCalloutRequest(id: id, anchor: anchor, width: width);

void _expectNoOverlap(List<BalanceCalloutPlacement> placed) {
  for (final a in placed) {
    for (final b in placed) {
      if (identical(a, b) || a.row != b.row) continue;
      expect(
        a.end <= b.start || b.end <= a.start,
        isTrue,
        reason: '${a.id} and ${b.id} overlap in row ${a.row}',
      );
    }
  }
}

void main() {
  test('a lone callout centres over its anchor', () {
    final placed = placeBalanceCallouts([_r('a', 100, 40)], laneWidth: 300);
    expect(placed.single.start, 80);
    expect(placed.single.row, 0);
  });

  test('a callout near an edge stays inside the lane', () {
    final left = placeBalanceCallouts([_r('a', 5, 40)], laneWidth: 300);
    expect(left.single.start, 0);
    final right = placeBalanceCallouts([_r('a', 298, 40)], laneWidth: 300);
    expect(right.single.end, 300);
  });

  test('neighbours push apart in one row, keeping their order', () {
    final placed = placeBalanceCallouts([
      _r('b', 110, 60),
      _r('a', 100, 60),
    ], laneWidth: 300);
    expect(placed.map((p) => p.row).toSet(), {0});
    _expectNoOverlap(placed);
    final a = placed.firstWhere((p) => p.id == 'a');
    final b = placed.firstWhere((p) => p.id == 'b');
    expect(a.end, lessThanOrEqualTo(b.start));
  });

  test('a crowd against the far edge is pushed back inside', () {
    final placed = placeBalanceCallouts([
      _r('a', 290, 60),
      _r('b', 295, 60),
      _r('c', 299, 60),
    ], laneWidth: 300);
    _expectNoOverlap(placed);
    for (final p in placed) {
      expect(p.start, greaterThanOrEqualTo(0));
      expect(p.end, lessThanOrEqualTo(300));
    }
    expect(placed.map((p) => p.row).toSet(), {0});
  });

  test('more than one row holds takes a second row', () {
    final placed = placeBalanceCallouts([
      for (var i = 0; i < 4; i++) _r('$i', 40.0 + i * 70, 100),
    ], laneWidth: 300);
    expect(placed.map((p) => p.row).toSet(), {0, 1});
    _expectNoOverlap(placed);
  });

  test('rows needed counts the rows used, at least one', () {
    expect(balanceCalloutRows(const []), 1);
    final placed = placeBalanceCallouts([
      for (var i = 0; i < 4; i++) _r('$i', 40.0 + i * 70, 100),
    ], laneWidth: 300);
    expect(balanceCalloutRows(placed), 2);
  });

  test('a callout wider than the lane is pinned to its start', () {
    final placed = placeBalanceCallouts([_r('a', 50, 400)], laneWidth: 300);
    expect(placed.single.start, 0);
  });

  group('rows to hold', () {
    test('one row when nothing needs one, or everything fits', () {
      expect(balanceCalloutRowsToHold(const [], laneWidth: 300), 1);
      expect(balanceCalloutRowsToHold(const [100, 100], laneWidth: 300), 1);
    });

    test('enough rows for the widest share of each', () {
      // Two rows of two: 100 + 4 + 100 fits 300.
      expect(
        balanceCalloutRowsToHold(const [100, 100, 100, 100], laneWidth: 300),
        2,
      );
      // Not even two fit 150 side by side: one per row.
      expect(
        balanceCalloutRowsToHold(const [100, 100, 100, 100], laneWidth: 150),
        4,
      );
    });

    test('placement never needs more rows than it reserves', () {
      const widths = <double>[120, 60, 90, 75, 110];
      const lane = 300.0;
      final reserved = balanceCalloutRowsToHold(widths, laneWidth: lane);
      // Whatever order the parts end up in along the bar.
      for (var shift = 0; shift < widths.length; shift++) {
        final placed = placeBalanceCallouts([
          for (var i = 0; i < widths.length; i++)
            _r('$i', ((i + shift) % widths.length) * 60.0, widths[i]),
        ], laneWidth: lane);
        expect(balanceCalloutRows(placed), lessThanOrEqualTo(reserved));
      }
    });
  });

  test('nothing to place gives nothing back', () {
    expect(placeBalanceCallouts(const [], laneWidth: 300), isEmpty);
  });
}
