import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/auto_update/data/repositories/update_preferences.dart';

void main() {
  late UpdatePreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    prefs = UpdatePreferences(sp);
  });

  group('UpdatePreferences', () {
    test('autoUpdateEnabled defaults to true', () {
      expect(prefs.autoUpdateEnabled, true);
    });

    test('setAutoUpdateEnabled persists value', () async {
      await prefs.setAutoUpdateEnabled(false);
      expect(prefs.autoUpdateEnabled, false);
    });

    test('lastCheckTime defaults to null', () {
      expect(prefs.lastCheckTime, isNull);
    });

    test('setLastCheckTime persists value', () async {
      final time = DateTime(2026, 2, 14, 12, 0);
      await prefs.setLastCheckTime(time);
      expect(prefs.lastCheckTime, time);
    });

    test('checkIntervalHours defaults to 4', () {
      expect(prefs.checkIntervalHours, 4);
    });

    test('setCheckIntervalHours persists value', () async {
      await prefs.setCheckIntervalHours(12);
      expect(prefs.checkIntervalHours, 12);
    });

    test('isDueForCheck returns true when no previous check', () {
      expect(prefs.isDueForCheck, true);
    });

    test('isDueForCheck returns false right after a check', () async {
      await prefs.setLastCheckTime(DateTime.now());
      expect(prefs.isDueForCheck, false);
    });

    test('isDueForCheck returns true when interval has elapsed', () async {
      final oldTime = DateTime.now().subtract(const Duration(hours: 5));
      await prefs.setLastCheckTime(oldTime);
      expect(prefs.isDueForCheck, true);
    });
  });
}
