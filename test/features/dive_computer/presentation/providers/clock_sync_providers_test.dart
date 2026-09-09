import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_computer/data/clock_sync_preferences.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClockSyncSettingsNotifier with storage', () {
    late SharedPreferences raw;
    late ClockSyncSettingsNotifier notifier;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'dive_computer_clock_sync_support.c9': 'unsupported',
      });
      raw = await SharedPreferences.getInstance();
      notifier = ClockSyncSettingsNotifier(ClockSyncPreferences(raw));
    });

    tearDown(() => notifier.dispose());

    test('seeds its state from the store', () {
      expect(notifier.state.supportFor('c9'), ClockSyncSupport.unsupported);
    });

    test('setGlobalEnabled updates state and persists', () async {
      await notifier.setGlobalEnabled(true);
      expect(notifier.state.globalEnabled, isTrue);
      expect(raw.getBool('dive_computer_clock_sync_enabled'), isTrue);
    });

    test('setOverride updates state and persists', () async {
      await notifier.setOverride('c1', ClockSyncOverride.always);
      expect(notifier.state.overrideFor('c1'), ClockSyncOverride.always);
      expect(raw.getString('dive_computer_clock_sync_override.c1'), 'always');
    });

    test('recordSupport keeps a definite answer and ignores failed', () async {
      await notifier.recordSupport('c1', ClockSyncStatus.synced);
      expect(notifier.state.supportFor('c1'), ClockSyncSupport.supported);
      expect(raw.getString('dive_computer_clock_sync_support.c1'), 'supported');

      await notifier.recordSupport('c1', ClockSyncStatus.failed);
      expect(notifier.state.supportFor('c1'), ClockSyncSupport.supported);

      await notifier.recordSupport('c1', ClockSyncStatus.unsupported);
      expect(notifier.state.supportFor('c1'), ClockSyncSupport.unsupported);
    });

    test('clearSupport forgets the answer so the next download asks', () async {
      await notifier.clearSupport('c9');
      expect(notifier.state.supportFor('c9'), ClockSyncSupport.unknown);
      expect(raw.containsKey('dive_computer_clock_sync_support.c9'), isFalse);
    });

    test('forget drops every key for the computer', () async {
      await notifier.setOverride('c9', ClockSyncOverride.never);
      await notifier.forget('c9');
      expect(notifier.state.overrideFor('c9'), ClockSyncOverride.inherit);
      expect(notifier.state.supportFor('c9'), ClockSyncSupport.unknown);
      expect(raw.containsKey('dive_computer_clock_sync_override.c9'), isFalse);
      expect(raw.containsKey('dive_computer_clock_sync_support.c9'), isFalse);
    });
  });

  group('clockSyncSettingsNotifierProvider', () {
    test('defaults to an unstored notifier that still works', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(clockSyncSettingsNotifierProvider).globalEnabled,
        isFalse,
      );
      await container
          .read(clockSyncSettingsNotifierProvider.notifier)
          .setGlobalEnabled(true);
      expect(
        container.read(clockSyncSettingsNotifierProvider).globalEnabled,
        isTrue,
      );
    });
  });
}
