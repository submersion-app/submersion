import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_settings_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoConnectKnownComputersNotifier with storage (issue #3361)', () {
    test('defaults to enabled when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = AutoConnectKnownComputersNotifier(prefs);
      addTearDown(notifier.dispose);

      expect(notifier.state, isTrue);
    });

    test('seeds its state from the stored value', () async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.autoConnectKnownComputers: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = AutoConnectKnownComputersNotifier(prefs);
      addTearDown(notifier.dispose);

      expect(notifier.state, isFalse);
    });

    test('setEnabled updates state and persists it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = AutoConnectKnownComputersNotifier(prefs);
      addTearDown(notifier.dispose);

      await notifier.setEnabled(false);

      expect(notifier.state, isFalse);
      expect(prefs.getBool(SettingsKeys.autoConnectKnownComputers), isFalse);
    });
  });

  group('AutoConnectKnownComputersNotifier.unstored', () {
    test('setEnabled changes state without storage behind it', () async {
      final notifier = AutoConnectKnownComputersNotifier.unstored(true);
      addTearDown(notifier.dispose);

      await notifier.setEnabled(false);

      expect(notifier.state, isFalse);
    });
  });
}
