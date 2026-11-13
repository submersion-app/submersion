import 'dart:ui';

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
      final runs = pinnedNdlRuns([59940]);
      expect(runs.single.single.value, 3600);
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

  group('maxDepthLabelOffset', () {
    const label = Size(30, 12);
    const area = Size(400, 44);

    test('label sits right of the dot', () {
      expect(
        maxDepthLabelOffset(
          dot: const Offset(100, 30),
          label: label,
          area: area,
        ),
        const Offset(106, 20),
      );
    });

    test('label flips left at the right edge', () {
      final at = maxDepthLabelOffset(
        dot: const Offset(390, 30),
        label: label,
        area: area,
      );
      expect(at.dx, 390 - 6 - 30);
    });

    test('label flips left of an NDL point in the way', () {
      final at = maxDepthLabelOffset(
        dot: const Offset(100, 30),
        label: label,
        area: area,
        avoid: const [Offset(115, 25)],
      );
      expect(at.dx, 64);
    });

    test('a dot at the bottom keeps the label inside the strip', () {
      final at = maxDepthLabelOffset(
        dot: const Offset(100, 44),
        label: label,
        area: area,
      );
      expect(at.dy + label.height, lessThanOrEqualTo(area.height));
    });

    test('with no room either side the label stays inside the strip', () {
      final at = maxDepthLabelOffset(
        dot: const Offset(15, 30),
        label: label,
        area: const Size(40, 44),
      );
      expect(at.dx, greaterThanOrEqualTo(0));
      expect(at.dx + label.width, lessThanOrEqualTo(40));
    });
  });
}
