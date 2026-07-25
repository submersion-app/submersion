import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/presentation/startup_brightness.dart';

Future<SharedPreferences> _prefsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveStartupBrightness', () {
    test('cached light wins over a dark platform', () async {
      final prefs = await _prefsWith({cachedThemeModeKey: 'light'});
      expect(
        resolveStartupBrightness(prefs, Brightness.dark),
        Brightness.light,
      );
    });

    test('cached dark wins over a light platform', () async {
      final prefs = await _prefsWith({cachedThemeModeKey: 'dark'});
      expect(
        resolveStartupBrightness(prefs, Brightness.light),
        Brightness.dark,
      );
    });

    test('cached system follows the platform', () async {
      final prefs = await _prefsWith({cachedThemeModeKey: 'system'});
      expect(
        resolveStartupBrightness(prefs, Brightness.light),
        Brightness.light,
      );
      expect(resolveStartupBrightness(prefs, Brightness.dark), Brightness.dark);
    });

    test('missing key follows the platform', () async {
      final prefs = await _prefsWith({});
      expect(resolveStartupBrightness(prefs, Brightness.dark), Brightness.dark);
      expect(
        resolveStartupBrightness(prefs, Brightness.light),
        Brightness.light,
      );
    });

    test('unrecognized value follows the platform', () async {
      final prefs = await _prefsWith({cachedThemeModeKey: 'blue'});
      expect(resolveStartupBrightness(prefs, Brightness.dark), Brightness.dark);
    });
  });

  group('cachedThemeModeValue', () {
    test('round-trips every ThemeMode through the resolver', () async {
      const cases = {
        (ThemeMode.light, Brightness.dark): Brightness.light,
        (ThemeMode.dark, Brightness.light): Brightness.dark,
        (ThemeMode.system, Brightness.dark): Brightness.dark,
        (ThemeMode.system, Brightness.light): Brightness.light,
      };
      for (final entry in cases.entries) {
        final (mode, platform) = entry.key;
        final prefs = await _prefsWith({
          cachedThemeModeKey: cachedThemeModeValue(mode),
        });
        expect(resolveStartupBrightness(prefs, platform), entry.value);
      }
    });
  });
}
