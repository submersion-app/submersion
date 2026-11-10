import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/info/dive_profile_info.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';

void main() {
  const config = ProfileLegendConfig(hasNdlData: true);

  test('a chart that leaves takes its overlays with it', () {
    final snapshot = ProfileLegendSnapshot();
    final chart = Object();

    snapshot.publish(chart, config);
    expect(snapshot.config, config);

    snapshot.release(chart);
    expect(snapshot.config, isNull);
  });

  test('a chart that leaves keeps the overlays its successor drew', () {
    final snapshot = ProfileLegendSnapshot();
    final old = Object();
    final successor = Object();
    const next = ProfileLegendConfig(hasCnsData: true);

    // The new chart builds before the old one is disposed.
    snapshot.publish(old, config);
    snapshot.publish(successor, next);
    snapshot.release(old);

    expect(snapshot.config, next);
  });
}
