import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/presentation/startup_theme.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';

Future<SharedPreferences> _prefsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveStartupThemePreset', () {
    test('returns the cached preset', () async {
      final prefs = await _prefsWith({cachedThemePresetKey: 'console'});
      expect(resolveStartupThemePreset(prefs).id, 'console');
    });

    test('falls back to the default when the key is missing', () async {
      final prefs = await _prefsWith({});
      expect(
        resolveStartupThemePreset(prefs).id,
        AppThemeRegistry.presets.first.id,
      );
    });

    test('falls back to the default for a retired preset id', () async {
      // A preset removed from the registry must not strand the splash: the
      // mirror can outlive the preset that wrote it.
      final prefs = await _prefsWith({cachedThemePresetKey: 'kelp'});
      expect(
        resolveStartupThemePreset(prefs).id,
        AppThemeRegistry.presets.first.id,
      );
    });
  });
}
