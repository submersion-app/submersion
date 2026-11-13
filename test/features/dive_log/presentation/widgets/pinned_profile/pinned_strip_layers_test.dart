import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_layers.dart';

List<List<int>> _indices(List<List<StripSeriesPoint>> runs) => [
  for (final run in runs) [for (final p in run) p.index],
];

void main() {
  group('pinnedNdlRuns', () {
    test('ndl runs break where NDL is spent', () {
      final runs = pinnedNdlRuns([600, 300, 0, -1, 0, 120]);
      expect(_indices(runs), [
        [0, 1],
        [5],
      ]);
    });

    test('ndl clamps past an hour', () {
      final runs = pinnedNdlRuns([59940, 1800]);
      expect(runs.single.first.value, 3600);
    });

    // Held at the top of its scale the line was a bar across most of a
    // recreational dive; it shows only where it dips below the top, dropping
    // in from the top edge and climbing back out to it (issue #4509).
    test('the line shows only where NDL dips below the top', () {
      final runs = pinnedNdlRuns([5940, 5940, 1800, 1200, 5940, 5940]);
      expect(_indices(runs), [
        [1, 2, 3, 4],
      ]);
      expect([for (final p in runs.single) p.value], [3600, 1800, 1200, 3600]);
    });

    test('an NDL that never dips below the top draws no line', () {
      expect(pinnedNdlRuns([5940, 3600, 5940]), isEmpty);
    });

    test('a dip that ends in deco does not reach back to the top', () {
      final runs = pinnedNdlRuns([5940, 1800, 0, -1, 1200, 5940]);
      expect(_indices(runs), [
        [0, 1],
        [4, 5],
      ]);
    });

    test('runs are worked out once per list', () {
      final curve = [600, 300, 0, 120];
      expect(identical(pinnedNdlRuns(curve), pinnedNdlRuns(curve)), isTrue);
    });

    test('a dense run keeps within the point budget', () {
      final curve = [for (var i = 0; i < 20000; i++) 3000 - i % 500];
      expect(
        pinnedNdlRuns(curve).single.length,
        lessThanOrEqualTo(kPinnedStripPointBudget),
      );
    });
  });

  group('pinnedDepthRuns', () {
    test('stepped depth runs keep only the steps', () {
      final runs = pinnedDepthRuns([0, 6, 6, 6, 3, 3, 0], stepped: true);
      expect(_indices(runs), [
        [1, 3, 4, 5],
      ]);
      expect([for (final p in runs.single) p.value], [6, 6, 3, 3]);
    });

    test('a smooth curve keeps every sample of a short run', () {
      final runs = pinnedDepthRuns([0, 1.5, 2.5, 0, 0, 1]);
      expect(_indices(runs), [
        [1, 2],
        [5],
      ]);
    });

    test('no obligation gives no runs', () {
      expect(pinnedDepthRuns([0, 0, 0], stepped: true), isEmpty);
    });

    test('stepped and smooth runs of one list are cached apart', () {
      final curve = <double>[0, 6, 6, 3, 0];
      final stepped = pinnedDepthRuns(curve, stepped: true);
      final smooth = pinnedDepthRuns(curve);
      expect(identical(stepped, pinnedDepthRuns(curve, stepped: true)), isTrue);
      expect(identical(smooth, pinnedDepthRuns(curve)), isTrue);
      expect(identical(stepped, smooth), isFalse);
    });
  });
}
