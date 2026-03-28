import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/debug_mode_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  late Directory tempDir;
  late LogFileService logFileService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('debug_mode_test_');
    logFileService = LogFileService(logDirectory: tempDir.path);
    await logFileService.initialize();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DebugModeNotifier', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('initial state is false when no preference stored', () {
      final notifier = DebugModeNotifier(prefs, logFileService);
      expect(notifier.state, isFalse);
    });

    test('initial state reads from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'debug_mode_enabled': true});
      prefs = await SharedPreferences.getInstance();
      final notifier = DebugModeNotifier(prefs, logFileService);
      expect(notifier.state, isTrue);
    });

    test('enable() sets state to true and persists', () async {
      final notifier = DebugModeNotifier(prefs, logFileService);
      await notifier.enable();
      expect(notifier.state, isTrue);
      expect(prefs.getBool('debug_mode_enabled'), isTrue);
    });

    test('disable() sets state to false and persists', () async {
      final notifier = DebugModeNotifier(prefs, logFileService);
      await notifier.enable();
      await notifier.disable();
      expect(notifier.state, isFalse);
      expect(prefs.getBool('debug_mode_enabled'), isFalse);
    });
  });

  group('debugModeNotifierProvider via ProviderContainer', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('reads false by default through provider', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          logFileServiceProvider.overrideWithValue(logFileService),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(debugModeNotifierProvider), isFalse);
    });

    test('enable() updates provider state to true', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          logFileServiceProvider.overrideWithValue(logFileService),
        ],
      );
      addTearDown(container.dispose);
      await container.read(debugModeNotifierProvider.notifier).enable();
      expect(container.read(debugModeNotifierProvider), isTrue);
    });

    test('disable() updates provider state back to false', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          logFileServiceProvider.overrideWithValue(logFileService),
        ],
      );
      addTearDown(container.dispose);
      await container.read(debugModeNotifierProvider.notifier).enable();
      await container.read(debugModeNotifierProvider.notifier).disable();
      expect(container.read(debugModeNotifierProvider), isFalse);
    });

    test('reads initial true value from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'debug_mode_enabled': true});
      prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          logFileServiceProvider.overrideWithValue(logFileService),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(debugModeNotifierProvider), isTrue);
    });
  });
}
