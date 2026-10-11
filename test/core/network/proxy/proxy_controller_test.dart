import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/proxy_settings_store.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

import '../../../support/fake_keychain_storage.dart';

/// Answers each resolve() only when the test completes its completer.
class _Resolver implements SystemProxyResolver {
  final answers = <Completer<SystemProxyResult>>[];
  int get calls => answers.length;

  @override
  Future<SystemProxyResult> resolve(Uri probe) {
    final c = Completer<SystemProxyResult>();
    answers.add(c);
    return c.future;
  }
}

/// A keychain whose reads wait until the test releases them.
class _SlowKeychain extends InMemoryKeychain {
  final release = Completer<void>();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    await release.future;
    return super.read(key: key);
  }
}

/// A keychain read that takes its value at once but answers only when the
/// test releases it, as a read already in flight when a write lands does.
class _SnapshotKeychain extends InMemoryKeychain {
  final release = Completer<void>();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final value = await super.read(key: key);
    await release.future;
    return value;
  }
}

/// A keychain that refuses every write, as a locked keychain does.
class _LockedKeychain extends InMemoryKeychain {
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw Exception('keychain locked');
}

/// A store whose first settings write waits until the test releases it.
class _SlowFirstSaveStore extends ProxySettingsStore {
  _SlowFirstSaveStore(super.prefs, {super.storage});

  final release = Completer<void>();
  var _saves = 0;

  @override
  Future<void> save(ProxySettings settings) async {
    if (_saves++ == 0) await release.future;
    await super.save(settings);
  }
}

const _fixed = SystemProxyFixed(type: ProxyType.http, host: 'corp', port: 8080);

void main() {
  late ProxySettingsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = ProxySettingsStore(
      await SharedPreferences.getInstance(),
      storage: InMemoryKeychain(),
    );
  });

  test('starts direct, then system mode applies the detected proxy', () async {
    final r = _Resolver();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    expect(c.current.isDirect, isTrue);
    final init = c.initialize(store);
    await pumpEventQueue();
    r.answers.single.complete(_fixed);
    await init;
    expect(c.current.endpoint, 'corp:8080');
    expect(c.state.system, _fixed);
    expect(c.state.detecting, isFalse);
  });

  test('startup stops waiting after the timeout and applies the late '
      'answer', () async {
    final r = _Resolver();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    await c.initialize(store, startupTimeout: const Duration(milliseconds: 10));
    expect(c.current.isDirect, isTrue);
    expect(c.state.detecting, isTrue);
    r.answers.single.complete(_fixed);
    await pumpEventQueue();
    expect(c.current.endpoint, 'corp:8080');
    expect(c.state.detecting, isFalse);
  });

  test('a slow answer never overwrites a newer choice', () async {
    final r = _Resolver();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    await c.initialize(store, startupTimeout: const Duration(milliseconds: 10));
    await c.saveSettings(ProxySettings.defaults.copyWith(mode: ProxyMode.none));
    r.answers.first.complete(_fixed);
    await pumpEventQueue();
    expect(c.current.isDirect, isTrue);
    expect(c.state.settings.mode, ProxyMode.none);
  });

  test('a stale refresh answer is dropped when a newer refresh '
      'started', () async {
    final r = _Resolver();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    final init = c.initialize(store);
    await pumpEventQueue();
    r.answers[0].complete(const SystemProxyNone());
    await init;
    final first = c.refresh();
    final second = c.refresh();
    r.answers[2].complete(_fixed);
    r.answers[1].complete(const SystemProxyNone());
    await Future.wait([first, second]);
    expect(c.current.endpoint, 'corp:8080');
  });

  test('manual mode loads the password and never asks the OS', () async {
    await store.save(
      const ProxySettings(
        mode: ProxyMode.manual,
        type: ProxyType.http,
        host: 'm',
        port: 3128,
        username: 'ann',
      ),
    );
    await store.savePassword('pw');
    final r = _Resolver();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    await c.initialize(store);
    expect(r.calls, 0);
    expect(c.current.username, 'ann');
    expect(c.current.password, 'pw');
    expect(c.manualPassword, 'pw');
  });

  test('saveSettings persists, updates the password only when asked, and '
      'emits', () async {
    final r = _Resolver();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    final init = c.initialize(store);
    await pumpEventQueue();
    r.answers.single.complete(const SystemProxyNone());
    await init;
    final emitted = <ProxyControllerState>[];
    final sub = c.changes.listen(emitted.add);
    addTearDown(sub.cancel);
    const manual = ProxySettings(
      mode: ProxyMode.manual,
      type: ProxyType.socks5,
      host: 's',
      port: 1080,
      username: 'u',
    );
    await c.saveSettings(manual, password: 'x', updatePassword: true);
    expect(store.load(), manual);
    expect(await store.loadPassword(), 'x');
    await c.saveSettings(manual.copyWith(host: 't'));
    expect(await store.loadPassword(), 'x');
    await pumpEventQueue();
    expect(
      emitted.map((s) => s.effective.host),
      containsAllInOrder(['s', 't']),
    );
    expect(c.current.kind, ProxyKind.socks5);
    expect(c.current.password, 'x');
  });

  test('switching to system mode detects again', () async {
    await store.save(ProxySettings.defaults.copyWith(mode: ProxyMode.none));
    final r = _Resolver();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    await c.initialize(store);
    expect(r.calls, 0);
    final save = c.saveSettings(ProxySettings.defaults);
    await pumpEventQueue();
    r.answers.single.complete(_fixed);
    await save;
    expect(c.current.endpoint, 'corp:8080');
  });

  test('a saved manual password is used after starting in another '
      'mode', () async {
    await store.save(
      const ProxySettings(
        mode: ProxyMode.none,
        type: ProxyType.http,
        host: 'm',
        port: 3128,
        username: 'ann',
      ),
    );
    await store.savePassword('pw');
    final c = ProxyController(resolver: _Resolver());
    addTearDown(c.dispose);
    await c.initialize(store);
    // Not read at startup: No proxy never uses it.
    expect(c.manualPassword, isNull);
    await c.saveSettings(c.state.settings.copyWith(mode: ProxyMode.manual));
    expect(c.manualPassword, 'pw');
    expect(c.current.username, 'ann');
    expect(c.current.password, 'pw');
  });

  test('a password read still pending never overrides a newer '
      'choice', () async {
    SharedPreferences.setMockInitialValues({});
    final keychain = _SlowKeychain();
    final slowStore = ProxySettingsStore(
      await SharedPreferences.getInstance(),
      storage: keychain,
    );
    await slowStore.save(
      const ProxySettings(
        mode: ProxyMode.none,
        type: ProxyType.http,
        host: 'm',
        port: 3128,
        username: 'ann',
      ),
    );
    final c = ProxyController(resolver: _Resolver());
    addTearDown(c.dispose);
    await c.initialize(slowStore);
    final toManual = c.saveSettings(
      c.state.settings.copyWith(mode: ProxyMode.manual),
    );
    await pumpEventQueue();
    await c.saveSettings(c.state.settings.copyWith(mode: ProxyMode.none));
    keychain.release.complete();
    await toManual;
    expect(c.state.settings.mode, ProxyMode.none);
    expect(c.current.isDirect, isTrue);
  });

  test(
    'a keychain read in flight never replaces a newer saved password',
    () async {
      final keychain = _SnapshotKeychain();
      final slowStore = ProxySettingsStore(
        await SharedPreferences.getInstance(),
        storage: keychain,
      );
      const manual = ProxySettings(
        mode: ProxyMode.manual,
        type: ProxyType.http,
        host: 'm',
        port: 3128,
        username: 'ann',
      );
      await slowStore.save(manual.copyWith(mode: ProxyMode.none));
      await slowStore.savePassword('old');
      final c = ProxyController(resolver: _Resolver());
      addTearDown(c.dispose);
      await c.initialize(slowStore);
      // Switching to Manual starts the lazy read, which has already seen 'old'.
      final toManual = c.saveSettings(manual);
      await pumpEventQueue();
      await c.saveSettings(manual, password: 'new', updatePassword: true);
      keychain.release.complete();
      await toManual;
      await c.refresh();
      expect(c.manualPassword, 'new');
      expect(c.current.password, 'new');
    },
  );

  test(
    'a refused password write leaves the saved settings as they were',
    () async {
      final locked = ProxySettingsStore(
        await SharedPreferences.getInstance(),
        storage: _LockedKeychain(),
      );
      await locked.save(ProxySettings.defaults.copyWith(mode: ProxyMode.none));
      final c = ProxyController(resolver: _Resolver());
      addTearDown(c.dispose);
      await c.initialize(locked);
      await expectLater(
        c.saveSettings(
          const ProxySettings(
            mode: ProxyMode.manual,
            type: ProxyType.http,
            host: 'm',
            port: 3128,
            username: 'ann',
          ),
          password: 'pw',
          updatePassword: true,
        ),
        throwsException,
      );
      // A restart must not load Manual without the password that goes with it.
      expect(locked.load().mode, ProxyMode.none);
      expect(locked.load().host, '');
    },
  );

  test('saves apply in the order they were made, however long each write '
      'takes', () async {
    await store.save(ProxySettings.defaults.copyWith(mode: ProxyMode.none));
    final c = ProxyController(resolver: _Resolver());
    addTearDown(c.dispose);
    final reopened = _SlowFirstSaveStore(
      await SharedPreferences.getInstance(),
      storage: InMemoryKeychain(),
    );
    await c.initialize(reopened);
    final first = c.saveSettings(
      ProxySettings.defaults.copyWith(mode: ProxyMode.manual),
    );
    final second = c.saveSettings(
      ProxySettings.defaults.copyWith(mode: ProxyMode.none),
    );
    await pumpEventQueue();
    reopened.release.complete();
    await Future.wait([first, second]);
    expect(c.state.settings.mode, ProxyMode.none);
    expect(reopened.load().mode, ProxyMode.none);
  });

  test('a resolver that throws leaves the app direct', () async {
    final c = ProxyController(resolver: _Throwing());
    addTearDown(c.dispose);
    await c.initialize(store);
    expect(c.current.isDirect, isTrue);
    expect(
      c.state.system,
      isA<SystemProxyUnavailable>().having(
        (u) => u.reason,
        'reason',
        SystemProxyUnavailableReason.platformError,
      ),
    );
  });
}

class _Throwing implements SystemProxyResolver {
  @override
  Future<SystemProxyResult> resolve(Uri probe) async => throw StateError('x');
}
