import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  test('a diver who has set nothing gets the dive computer per metric', () {
    const settings = AppSettings();

    expect(settings.defaultNdlSource, MetricDataSource.computer);
    expect(settings.defaultCeilingSource, MetricDataSource.computer);
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
}
