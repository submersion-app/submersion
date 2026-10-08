import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  test('a diver who has set nothing gets the dive computer per metric', () {
    const settings = AppSettings();

    expect(settings.defaultNdlSource, MetricDataSource.computer);
    expect(settings.defaultDecoStopSource, MetricDataSource.computer);
    expect(settings.defaultTtsSource, MetricDataSource.computer);
    expect(settings.defaultCnsSource, MetricDataSource.computer);
    expect(settings.defaultGtrSource, MetricDataSource.computer);
  });

  test('an explicit calculated choice survives copyWith', () {
    const settings = AppSettings();
    final calculated = settings.copyWith(
      defaultNdlSource: MetricDataSource.calculated,
    );

    expect(calculated.defaultNdlSource, MetricDataSource.calculated);
    expect(calculated.defaultTtsSource, MetricDataSource.computer);
  });

  // The legend state has its own constructor defaults, used by any state built
  // without settings. They must name the same source as AppSettings, or that
  // state quietly disagrees with a new diver's default.
  test('a default legend state matches the settings defaults', () {
    const settings = AppSettings();
    const legend = ProfileLegendState();

    expect(legend.ndlSource, settings.defaultNdlSource);
    expect(legend.decoStopSource, settings.defaultDecoStopSource);
    expect(legend.ttsSource, settings.defaultTtsSource);
    expect(legend.cnsSource, settings.defaultCnsSource);
    expect(legend.gtrSource, settings.defaultGtrSource);
  });
}
