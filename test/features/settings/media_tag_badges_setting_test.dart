import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/media_badge_settings_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The device-local switch for the library's tag markers (issue #4218).
void main() {
  test('defaults to on when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = MediaTagBadgesNotifier(
      await SharedPreferences.getInstance(),
    );
    expect(notifier.state, isTrue);
  });

  test('starts from the stored choice', () async {
    SharedPreferences.setMockInitialValues({
      SettingsKeys.mediaTagBadges: false,
    });
    final notifier = MediaTagBadgesNotifier(
      await SharedPreferences.getInstance(),
    );
    expect(notifier.state, isFalse);
  });

  test('persists a change under its own key only', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = MediaTagBadgesNotifier(prefs);

    await notifier.setEnabled(false);

    expect(notifier.state, isFalse);
    expect(prefs.getBool(SettingsKeys.mediaTagBadges), isFalse);
    expect(prefs.getBool(SettingsKeys.mediaProvenanceBadges), isNull);
  });

  test('the unstored fallback changes state without storage', () async {
    final notifier = MediaTagBadgesNotifier.unstored(true);
    await notifier.setEnabled(false);
    expect(notifier.state, isFalse);
  });
}
