import 'dart:async';

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
