import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/presentation/providers/app_lock_provider.dart';
import 'package:submersion/core/services/security/database_security_key_store.dart';
import 'package:submersion/core/services/security/database_security_service.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    DatabaseSecurityService.instance.resetForTesting();
  });

  Future<ProviderContainer> makeContainer({
    required int timeoutMinutes,
    bool appLockEnabled = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'app_lock_enabled': appLockEnabled,
      'app_lock_timeout_minutes': timeoutMinutes,
    });
    final prefs = await SharedPreferences.getInstance();
    DatabaseSecurityService.instance.resetForTesting();
    await DatabaseSecurityService.instance.configure(
      prefs: prefs,
      keyStore: DatabaseSecurityKeyStore(storage: InMemoryKeychain()),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('locks after timeout elapses in background', () async {
    final container = await makeContainer(timeoutMinutes: 5);
    final notifier = container.read(appLockNotifierProvider.notifier);
    withClock(Clock.fixed(DateTime(2026, 8, 6, 12, 0)), () {
      notifier.noteBackgrounded();
    });
    withClock(Clock.fixed(DateTime(2026, 8, 6, 12, 6)), () {
      notifier.noteResumed();
    });
    expect(container.read(appLockNotifierProvider), true);
  });

  test('does not lock before timeout', () async {
    final container = await makeContainer(timeoutMinutes: 5);
    final notifier = container.read(appLockNotifierProvider.notifier);
    withClock(Clock.fixed(DateTime(2026, 8, 6, 12, 0)), () {
      notifier.noteBackgrounded();
    });
    withClock(Clock.fixed(DateTime(2026, 8, 6, 12, 3)), () {
      notifier.noteResumed();
    });
    expect(container.read(appLockNotifierProvider), false);
  });

  test('first backgrounded timestamp wins across repeat events', () async {
    final container = await makeContainer(timeoutMinutes: 5);
    final notifier = container.read(appLockNotifierProvider.notifier);
    withClock(Clock.fixed(DateTime(2026, 8, 6, 12, 0)), () {
      notifier.noteBackgrounded();
    });
    // A later inactive/paused event must not reset the clock.
    withClock(Clock.fixed(DateTime(2026, 8, 6, 12, 4)), () {
      notifier.noteBackgrounded();
    });
    withClock(Clock.fixed(DateTime(2026, 8, 6, 12, 6)), () {
      notifier.noteResumed();
    });
    expect(container.read(appLockNotifierProvider), true);
  });

  test('timeout -1 never locks; 0 locks immediately', () async {
    final never = await makeContainer(timeoutMinutes: -1);
    final n1 = never.read(appLockNotifierProvider.notifier);
    n1.noteBackgrounded();
    n1.noteResumed();
    expect(never.read(appLockNotifierProvider), false);

    final immediate = await makeContainer(timeoutMinutes: 0);
    final n2 = immediate.read(appLockNotifierProvider.notifier);
    n2.noteBackgrounded();
    n2.noteResumed();
    expect(immediate.read(appLockNotifierProvider), true);
  });

  test('no-op entirely when app lock disabled', () async {
    final container = await makeContainer(
      timeoutMinutes: 0,
      appLockEnabled: false,
    );
    final notifier = container.read(appLockNotifierProvider.notifier);
    notifier.noteBackgrounded();
    notifier.noteResumed();
    expect(container.read(appLockNotifierProvider), false);
  });

  test(
    'no-op (and no throw) when the security service is unconfigured',
    () async {
      DatabaseSecurityService.instance.resetForTesting();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(appLockNotifierProvider.notifier);
      expect(() {
        notifier.noteBackgrounded();
        notifier.noteResumed();
      }, returnsNormally);
      expect(container.read(appLockNotifierProvider), false);
    },
  );
}
