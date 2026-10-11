import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_refresh_triggers.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';

class _Counting implements SystemProxyResolver {
  int calls = 0;

  @override
  Future<SystemProxyResult> resolve(Uri probe) async {
    calls++;
    return const SystemProxyNone();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resume refreshes at most once per interval', () async {
    final r = _Counting();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    final changes = StreamController<Object?>();
    addTearDown(changes.close);
    var now = DateTime(2026, 10, 10, 12);
    final t = ProxyRefreshTriggers(
      c,
      networkChanges: changes.stream,
      listenToLifecycle: false,
      clock: () => now,
    );
    addTearDown(t.dispose);
    t.onResume();
    t.onResume();
    await pumpEventQueue();
    expect(r.calls, 1);
    now = now.add(const Duration(minutes: 2));
    t.onResume();
    await pumpEventQueue();
    expect(r.calls, 2);
  });

  test('a network change refreshes; dispose stops listening', () async {
    final r = _Counting();
    final c = ProxyController(resolver: r);
    addTearDown(c.dispose);
    final changes = StreamController<Object?>();
    addTearDown(changes.close);
    final t = ProxyRefreshTriggers(
      c,
      networkChanges: changes.stream,
      listenToLifecycle: false,
    );
    changes.add(null);
    await pumpEventQueue();
    expect(r.calls, 1);
    t.dispose();
    changes.add(null);
    await pumpEventQueue();
    expect(r.calls, 1);
  });
}
