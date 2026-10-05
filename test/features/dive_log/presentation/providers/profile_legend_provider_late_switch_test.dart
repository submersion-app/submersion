import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ProviderContainer containerWith(AppSettings settings) {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _StubSettingsNotifier(settings)),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(profileLegendProvider, (_, _) {});
    addTearDown(sub.close);
    return container;
  }

  test('late gas switches show by default', () {
    final container = containerWith(const AppSettings());
    expect(container.read(profileLegendProvider).showLateGasSwitches, isTrue);
  });

  test('seeds from the diver default', () {
    final container = containerWith(
      const AppSettings(defaultShowLateGasSwitches: false),
    );
    expect(container.read(profileLegendProvider).showLateGasSwitches, isFalse);
  });

  test('toggles for the session', () {
    final container = containerWith(const AppSettings());
    container.read(profileLegendProvider.notifier).toggleLateGasSwitches();
    expect(container.read(profileLegendProvider).showLateGasSwitches, isFalse);
  });
}
