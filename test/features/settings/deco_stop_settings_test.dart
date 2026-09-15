import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  test('deco stop settings default to visible and the computer', () {
    const settings = AppSettings();
    expect(settings.showDecoStopsOnProfile, isTrue);
    expect(settings.defaultDecoStopSource, MetricDataSource.computer);
  });

  test('copyWith updates the deco stop settings independently', () {
    const settings = AppSettings();

    final hidden = settings.copyWith(showDecoStopsOnProfile: false);
    expect(hidden.showDecoStopsOnProfile, isFalse);
    expect(hidden.defaultDecoStopSource, MetricDataSource.computer);
    expect(hidden.showCeilingOnProfile, settings.showCeilingOnProfile);

    final calculated = settings.copyWith(
      defaultDecoStopSource: MetricDataSource.calculated,
    );
    expect(calculated.defaultDecoStopSource, MetricDataSource.calculated);
    expect(calculated.defaultCeilingSource, settings.defaultCeilingSource);
    expect(calculated.showDecoStopsOnProfile, isTrue);
  });
}
