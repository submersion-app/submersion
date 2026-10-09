import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/icd_calculator_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// A settings notifier a test can push new values into directly, unlike
/// [SettingsNotifier] itself, which persists through a repository.
class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Regression test for a Copilot review finding on PR #3125: the provider
  // used to read settingsProvider once at creation (a StateProvider seeded
  // via ref.read), so a later settings change -- the Settings page toggle,
  // or sync adopting a peer's value -- never reached an already-built
  // calculator. It is now a plain derived provider that watches the
  // setting, so it must follow every change, not just the first read.
  test('icdWarningsEnabledProvider follows a later settings change', () {
    final notifier = _FixedSettings(
      const AppSettings(icdWarningsEnabled: true),
    );
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith((ref) => notifier)],
    );
    addTearDown(container.dispose);

    expect(container.read(icdWarningsEnabledProvider), isTrue);

    notifier.state = notifier.state.copyWith(icdWarningsEnabled: false);

    expect(container.read(icdWarningsEnabledProvider), isFalse);
  });
}
