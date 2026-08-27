import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_series_cache.dart';

void main() {
  test('returns the same instance on a key hit (no rebuild)', () {
    final cache = ChartSeriesCache<FlSpot>();
    var builds = 0;
    List<FlSpot> build() {
      builds++;
      return [const FlSpot(0, 0)];
    }

    final a = cache.series('depth', 'sigA', build);
    final b = cache.series('depth', 'sigA', build);
    expect(identical(a, b), isTrue);
    expect(builds, 1);
  });

  test('a changed signature rebuilds; an unchanged one does not', () {
    final cache = ChartSeriesCache<FlSpot>();
    var builds = 0;
    List<FlSpot> build() {
      builds++;
      return [const FlSpot(0, 0)];
    }

    cache.series('depth', 'sigA', build);
    cache.series('depth', 'sigA', build);
    expect(builds, 1);

    cache.series('depth', 'sigB', build);
    expect(builds, 2);
  });

  test('signature changes are scoped per key', () {
    final cache = ChartSeriesCache<FlSpot>();
    var depthBuilds = 0;
    var analysisBuilds = 0;

    List<FlSpot> buildDepth() {
      depthBuilds++;
      return [const FlSpot(0, 0)];
    }

    List<FlSpot> buildAnalysis() {
      analysisBuilds++;
      return [const FlSpot(1, 1)];
    }

    final depth = cache.series('depth', 'base-sig', buildDepth);
    cache.series('analysis', 'curves-v1', buildAnalysis);

    // The analysis curves re-emit (e.g. ceiling-source toggle): only the
    // analysis key rebuilds; depth stays the identical cached instance.
    cache.series('analysis', 'curves-v2', buildAnalysis);
    final depthAgain = cache.series('depth', 'base-sig', buildDepth);

    expect(analysisBuilds, 2);
    expect(depthBuilds, 1);
    expect(identical(depth, depthAgain), isTrue);
  });

  test('distinct keys are cached independently', () {
    final cache = ChartSeriesCache<FlSpot>();
    final depth = cache.series('depth', 's', () => [const FlSpot(0, 0)]);
    final temp = cache.series('temp', 's', () => [const FlSpot(1, 1)]);
    expect(identical(cache.series('depth', 's', () => []), depth), isTrue);
    expect(identical(cache.series('temp', 's', () => []), temp), isTrue);
  });
}
