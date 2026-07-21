import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  test('deco stop settings default to visible and calculated', () {
    const settings = AppSettings();
    expect(settings.showDecoStopsOnProfile, isTrue);
    expect(settings.defaultDecoStopSource, MetricDataSource.calculated);
  });

  test('copyWith updates the deco stop settings independently', () {
    const settings = AppSettings();

    final hidden = settings.copyWith(showDecoStopsOnProfile: false);
    expect(hidden.showDecoStopsOnProfile, isFalse);
    expect(hidden.defaultDecoStopSource, MetricDataSource.calculated);
    expect(hidden.showCeilingOnProfile, settings.showCeilingOnProfile);

    final computer = settings.copyWith(
      defaultDecoStopSource: MetricDataSource.computer,
    );
    expect(computer.defaultDecoStopSource, MetricDataSource.computer);
    expect(computer.defaultCeilingSource, settings.defaultCeilingSource);
    expect(computer.showDecoStopsOnProfile, isTrue);
  });
}
