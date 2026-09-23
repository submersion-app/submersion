import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/o2_cell_spread.dart';
import 'package:submersion/core/constants/o2_cell_unit.dart';

void main() {
  group('computeO2CellRange', () {
    test('is the gap between the highest and lowest reporting cell', () {
      final range = computeO2CellRange([
        [58],
        [61],
        [43],
      ]);
      expect(range.single, 18.0);
    });

    test('is zero when every cell agrees', () {
      final range = computeO2CellRange([
        [63],
        [63],
        [63],
      ]);
      expect(range.single, 0.0);
    });

    test('needs at least two cells to mean anything', () {
      expect(
        computeO2CellRange([
          [58],
        ]).single,
        isNull,
      );
      expect(
        computeO2CellRange([
          [58],
          [null],
        ]).single,
        isNull,
      );
    });

    test('has one value per sample, not per cell', () {
      final range = computeO2CellRange([
        [58, 59, 60],
        [61, 62, 70],
      ]);
      expect(range, hasLength(3));
      expect(range[2], 10.0);
    });

    test('empty input yields an empty curve', () {
      expect(computeO2CellRange(const []), isEmpty);
    });
  });

  group('smoothO2CellSpread', () {
    test('a window of one leaves the curves untouched', () {
      final input = [
        [0.0, 1.0, -1.0],
      ];
      expect(smoothO2CellSpread(input, windowSamples: 1), input);
    });

    test('removes the one-millivolt jitter that quantization creates', () {
      final jitter = [
        [-1.0, 0.0, -1.0, -1.0, 0.0, -1.0, -1.0, 0.0, -1.0],
      ];
      final smoothed = smoothO2CellSpread(jitter, windowSamples: 5);
      expect(smoothed.single, everyElement(-1.0));
    });

    test('a sustained drift survives smoothing', () {
      final drift = [
        [0.0, 0.0, 0.0, 0.0, 0.0, -20.0, -20.0, -20.0, -20.0, -20.0],
      ];
      final smoothed = smoothO2CellSpread(drift, windowSamples: 3);
      expect(smoothed.single.first, 0.0);
      expect(smoothed.single.last, -20.0);
    });

    test('a lone spike is rejected, unlike a mean', () {
      final spike = [
        [0.0, 0.0, 12.0, 0.0, 0.0],
      ];
      final smoothed = smoothO2CellSpread(spike, windowSamples: 3);
      expect(smoothed.single[2], 0.0);
    });

    test('gaps stay gaps', () {
      final withGap = [
        [0.0, null, 0.0, 0.0, 0.0],
      ];
      final smoothed = smoothO2CellSpread(withGap, windowSamples: 3);
      expect(smoothed.single[1], isNull);
      expect(smoothed.single[0], 0.0);
    });

    test('edges use the samples that exist rather than going null', () {
      final input = [
        [-1.0, -1.0, -1.0, -1.0, -1.0],
      ];
      final smoothed = smoothO2CellSpread(input, windowSamples: 5);
      expect(smoothed.single.first, -1.0);
      expect(smoothed.single.last, -1.0);
    });

    test('preserves shape and handles empty input', () {
      expect(smoothO2CellSpread(const [], windowSamples: 5), isEmpty);
      final shaped = smoothO2CellSpread([
        [0.0, 1.0],
        [1.0, 0.0],
      ], windowSamples: 3);
      expect(shaped, hasLength(2));
      expect(shaped[0], hasLength(2));
    });
  });

  group('o2CellSpreadWindowSamples', () {
    test('spans about two minutes at a ten-second sample interval', () {
      final timestamps = [for (var t = 0; t < 600; t += 10) t];
      expect(o2CellSpreadWindowSamples(timestamps), 13);
    });

    test('scales with a denser sample interval', () {
      final timestamps = [for (var t = 0; t < 600; t += 2) t];
      expect(o2CellSpreadWindowSamples(timestamps), 61);
    });

    test('always returns an odd window so it can be centered', () {
      for (final step in [1, 2, 3, 5, 10, 20, 30]) {
        final timestamps = [for (var t = 0; t < 1200; t += step) t];
        expect(o2CellSpreadWindowSamples(timestamps).isOdd, isTrue);
      }
    });

    test('degrades safely on profiles too short or irregular to measure', () {
      expect(o2CellSpreadWindowSamples(const []), 1);
      expect(o2CellSpreadWindowSamples(const [0]), 1);
      expect(o2CellSpreadWindowSamples(const [5, 5, 5]), 1);
    });

    test('never grows without bound on a very dense profile', () {
      final timestamps = [for (var t = 0; t < 1200; t++) t];
      expect(o2CellSpreadWindowSamples(timestamps), lessThanOrEqualTo(121));
    });
  });

  group('o2CellAgreementFor', () {
    test('classifies by how far apart the cells are', () {
      expect(o2CellAgreementFor(0), O2CellAgreement.tight);
      expect(o2CellAgreementFor(2), O2CellAgreement.tight);
      expect(o2CellAgreementFor(kO2CellDriftingMv), O2CellAgreement.drifting);
      expect(o2CellAgreementFor(8), O2CellAgreement.drifting);
      expect(o2CellAgreementFor(kO2CellWideMv), O2CellAgreement.wide);
      expect(o2CellAgreementFor(30), O2CellAgreement.wide);
    });

    test('a few millivolts of normal cell variation reads as tight', () {
      // Real rigs sit 1-3 mV apart all dive; that must not look like a problem.
      for (final mv in [0.0, 1.0, 2.0, 3.0]) {
        expect(o2CellAgreementFor(mv), O2CellAgreement.tight);
      }
    });
  });

  group('o2CellAgreementRuns', () {
    test('collapses a steady dive into a single run', () {
      final runs = o2CellAgreementRuns([1.0, 1.0, 2.0, 1.0]);
      expect(runs, hasLength(1));
      expect(runs.single.level, O2CellAgreement.tight);
      expect(runs.single.startIndex, 0);
      expect(runs.single.endIndex, 3);
    });

    test('splits where the level changes', () {
      final runs = o2CellAgreementRuns([1.0, 1.0, 8.0, 8.0, 1.0]);
      expect(runs.map((r) => r.level).toList(), [
        O2CellAgreement.tight,
        O2CellAgreement.drifting,
        O2CellAgreement.tight,
      ]);
      expect(runs[1].startIndex, 2);
      expect(runs[1].endIndex, 3);
    });

    test('a gap breaks the run rather than bridging it', () {
      final runs = o2CellAgreementRuns([1.0, null, 1.0]);
      expect(runs, hasLength(2));
      expect(runs[0].endIndex, 0);
      expect(runs[1].startIndex, 2);
    });

    test('a single sample still produces a run it can be drawn from', () {
      final runs = o2CellAgreementRuns([20.0]);
      expect(runs, hasLength(1));
      expect(runs.single.level, O2CellAgreement.wide);
      expect(runs.single.startIndex, 0);
      expect(runs.single.endIndex, 0);
    });

    test('no data yields no runs', () {
      expect(o2CellAgreementRuns(const []), isEmpty);
      expect(o2CellAgreementRuns([null, null]), isEmpty);
    });

    test('a long steady dive stays cheap to draw', () {
      // Run-length encoding is what keeps the rug to a handful of segments
      // instead of one per sample.
      final runs = o2CellAgreementRuns(List.filled(5000, 1.0));
      expect(runs, hasLength(1));
    });
  });

  group('agreement in bar', () {
    test('the same gap reads differently in each unit', () {
      // 0.12 bar is a drifting gap; as a bare number it would be tight on the
      // millivolt scale, which is why the unit travels with the spread.
      expect(
        o2CellAgreementFor(0.12, unit: O2CellUnit.ppO2),
        O2CellAgreement.drifting,
      );
      expect(
        o2CellAgreementFor(0.12, unit: O2CellUnit.millivolts),
        O2CellAgreement.tight,
      );
    });

    test('bar thresholds bracket the three levels', () {
      const u = O2CellUnit.ppO2;
      expect(o2CellAgreementFor(0.05, unit: u), O2CellAgreement.tight);
      expect(
        o2CellAgreementFor(kO2CellDriftingBar, unit: u),
        O2CellAgreement.drifting,
      );
      expect(o2CellAgreementFor(kO2CellWideBar, unit: u), O2CellAgreement.wide);
    });

    test('millivolts stay the default so existing callers are unchanged', () {
      expect(o2CellAgreementFor(kO2CellWideMv), O2CellAgreement.wide);
    });

    test('runs are cut at the unit thresholds they are given', () {
      final spread = <double?>[0.02, 0.02, 0.30, 0.30];
      expect(
        o2CellAgreementRuns(
          spread,
          unit: O2CellUnit.ppO2,
        ).map((r) => r.level).toList(),
        [O2CellAgreement.tight, O2CellAgreement.wide],
      );
      // Read as millivolts the whole stretch is tight, so it is one run.
      expect(o2CellAgreementRuns(spread), hasLength(1));
    });

    test('a spread of ppO2 values is computed the same way', () {
      final range = computeO2CellRange(<List<num?>>[
        <double?>[1.13, 1.20],
        <double?>[1.71, 1.22],
      ]);
      expect(range[0], closeTo(0.58, 1e-9));
      expect(range[1], closeTo(0.02, 1e-9));
    });
  });
}
