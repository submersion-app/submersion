import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/planner/presentation/widgets/logged/logged_dive_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Issue #4593: the planner's logged-dive chart follows the diver's default
/// for the buoyancy line, as every logged-dive profile does.
void main() {
  ProviderContainer container(AppSettings settings) {
    final c = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _StubSettingsNotifier(settings)),
        ...loggedDiveChartOverrides,
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(profileLegendProvider, (_, _) {});
    addTearDown(sub.close);
    return c;
  }

  test('planner logged chart follows the default', () {
    expect(
      container(
        const AppSettings(defaultShowBuoyancy: true),
      ).read(profileLegendProvider).showBuoyancy,
      isTrue,
    );
    expect(
      container(const AppSettings()).read(profileLegendProvider).showBuoyancy,
      isFalse,
    );
  });
}
