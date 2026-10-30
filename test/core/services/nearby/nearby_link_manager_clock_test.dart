import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';

import '../../../support/in_memory_nearby_carrier.dart';
import '../../../support/nearby_link_harness.dart';

/// A clock set back (by hand, or by a network time correction) never makes
/// the link wait longer than its own spacing (issue #3731).
void main() {
  late InMemoryNearbyHub hub;

  setUp(() => hub = InMemoryNearbyHub());

  Future<NearbyTestDevice> device(String id) => joinNearbyTestDevice(hub, id);

  const back = Duration(hours: 1);

  test('the per-peer cooldown', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    await foregroundNearbyTestDevices([a, b]);
    expect(a.engine.recordedAcks, hasLength(1));

    a.now = a.now.subtract(back);
    await a.manager.refresh();
    await settleNearby();
    expect(a.engine.recordedAcks, hasLength(2));
  });

  test('the retry spacing after a failed connect', () async {
    final a = await device('A')
      ..retryAfter = const Duration(seconds: 30);
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    a.carrier.refuseConnects = true;
    b.carrier.refuseConnects = true;
    await foregroundNearbyTestDevices([a, b]);
    expect(a.engine.recordedAcks, isEmpty);

    a.carrier.refuseConnects = false;
    a.now = a.now.subtract(back);
    await a.manager.refresh();
    await settleNearby();
    expect(a.engine.recordedAcks, hasLength(1));
  });

  test('the backoff for a stranger', () async {
    final a = await device('A');
    final stranger = await device('S');
    final c = await device('C');
    await pairNearbyTestDevices(a, c);
    await pairNearbyTestDevices(stranger, c); // so the stranger's radio runs
    var dials = 0;
    var clock = DateTime.utc(2026, 10, 27, 12);
    final manager = NearbyLinkManager(
      carrier: CountingNearbyCarrier(a.carrier, () => dials++),
      engine: a.engine,
      secrets: a.secrets,
      peers: a.peers,
      cursors: a.cursors,
      autoSyncEnabled: () => true,
      tempDir: () async => a.temp,
      now: () => clock,
      retryAfter: Duration.zero,
      scanRestartAfter: Duration.zero,
    );
    addTearDown(manager.dispose);
    await stranger.manager.setForeground(true);
    await manager.setForeground(true);
    await settleNearby();
    final first = dials;
    expect(first, greaterThan(0));

    clock = clock.subtract(back);
    await manager.refresh();
    await settleNearby();
    expect(dials, greaterThan(first));
  });

  test('the spacing between scan restarts', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    var starts = 0;
    var clock = DateTime.utc(2026, 10, 27, 12);
    final manager = NearbyLinkManager(
      carrier: CountingNearbyCarrier(
        a.carrier,
        () {},
        onStartScanning: () => starts++,
      ),
      engine: a.engine,
      secrets: a.secrets,
      peers: a.peers,
      cursors: a.cursors,
      autoSyncEnabled: () => true,
      tempDir: () async => a.temp,
      now: () => clock,
    );
    addTearDown(manager.dispose);
    await manager.setForeground(true);
    expect(starts, 1);

    clock = clock.subtract(back);
    await manager.refresh();
    expect(starts, 2);
  });
}
