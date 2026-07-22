import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';

void main() {
  test('deco stop legend state defaults to visible and calculated', () {
    const state = ProfileLegendState();
    expect(state.showDecoStops, isTrue);
    expect(state.decoStopSource, MetricDataSource.calculated);
  });

  test('copyWith toggles deco stops without touching the ceiling', () {
    const state = ProfileLegendState();
    final updated = state.copyWith(showDecoStops: false);

    expect(updated.showDecoStops, isFalse);
    expect(updated.showCeiling, state.showCeiling);
  });

  test('deco stop source is independent of the ceiling source', () {
    const state = ProfileLegendState();
    final updated = state.copyWith(decoStopSource: MetricDataSource.computer);

    expect(updated.decoStopSource, MetricDataSource.computer);
    expect(updated.ceilingSource, MetricDataSource.calculated);
  });

  test('equality accounts for the deco stop fields', () {
    const state = ProfileLegendState();
    expect(state.copyWith(showDecoStops: false) == state, isFalse);
    expect(
      state.copyWith(decoStopSource: MetricDataSource.computer) == state,
      isFalse,
    );
  });
}
