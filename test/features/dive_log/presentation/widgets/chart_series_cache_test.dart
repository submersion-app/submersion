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

    final a = cache.series('depth', build);
    final b = cache.series('depth', build);
    expect(identical(a, b), isTrue);
    expect(builds, 1);
  });

  test(
    'invalidate(newSignature) forces a rebuild; same signature does not',
    () {
      final cache = ChartSeriesCache<FlSpot>();
      var builds = 0;
      List<FlSpot> build() {
        builds++;
        return [const FlSpot(0, 0)];
      }

      cache.invalidate('sigA');
      cache.series('depth', build);
      cache.invalidate('sigA'); // unchanged -> keep cache
      cache.series('depth', build);
      expect(builds, 1);

      cache.invalidate('sigB'); // changed -> drop cache
      cache.series('depth', build);
      expect(builds, 2);
    },
  );

  test('distinct keys are cached independently', () {
    final cache = ChartSeriesCache<FlSpot>();
    final depth = cache.series('depth', () => [const FlSpot(0, 0)]);
    final temp = cache.series('temp', () => [const FlSpot(1, 1)]);
    expect(identical(cache.series('depth', () => []), depth), isTrue);
    expect(identical(cache.series('temp', () => []), temp), isTrue);
  });
}
