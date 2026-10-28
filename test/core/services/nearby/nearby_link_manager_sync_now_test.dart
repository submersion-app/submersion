import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_sync_protocol.dart';

import '../../../support/in_memory_nearby_carrier.dart';
import '../../../support/nearby_link_harness.dart';

/// Sync now finds its own device, and only that one, and the rows say
/// what the radio is doing (issue #3731).
void main() {
  late InMemoryNearbyHub hub;

  setUp(() => hub = InMemoryNearbyHub());

  Future<NearbyTestDevice> device(String id) => joinNearbyTestDevice(hub, id);

  test('Sync now right after a session dials its device at once, though '
      'the retry spacing has not passed', () async {
    final a = await device('A')
      ..retryAfter = const Duration(seconds: 30);
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    await foregroundNearbyTestDevices([a, b]);
    expect(a.engine.recordedAcks, hasLength(1));

    a.now = a.now.add(const Duration(seconds: 5));
    final outcome = await a.manager
        .syncNow('B')
        .timeout(const Duration(seconds: 2));
    expect(outcome, isNotNull);
    expect(outcome!.error, isNull);
    expect(a.engine.recordedAcks, hasLength(2));
  });

  test('Sync now leaves other paired devices to their own rules', () async {
    final a = await device('A');
    final b = await device('B');
    final c = await device('C');
    await pairNearbyTestDevices(a, b);
    await pairNearbyTestDevices(a, c);
    // A meets C first, so it knows C's address and C is inside its cooldown.
    await foregroundNearbyTestDevices([a, c]);
    expect(a.engine.recordedAcks.where((r) => r.peer == 'C'), hasLength(1));

    a.auto = false;
    await a.manager.refresh();
    await b.manager.setForeground(true);
    final outcome = await a.manager
        .syncNow('B')
        .timeout(const Duration(seconds: 2));
    await settleNearby();
    expect(outcome, isNotNull);
    expect(outcome!.error, isNull);
    expect(
      a.engine.recordedAcks.where((r) => r.peer == 'C'),
      hasLength(1),
      reason: 'only the device the diver asked for',
    );
  });

  test('a device Sync now dials before it knows its address runs no '
      'session once it turns out to be another one', () async {
    final a = await device('A');
    final b = await device('B');
    final c = await device('C');
    await pairNearbyTestDevices(a, b);
    await pairNearbyTestDevices(a, c);
    // C meets A by dialling it, so A never learns C's address.
    a.carrier.refuseConnects = true;
    await foregroundNearbyTestDevices([a, c]);
    expect(a.engine.recordedAcks.where((r) => r.peer == 'C'), hasLength(1));

    a.carrier.refuseConnects = false;
    a.auto = false;
    await a.manager.refresh();
    await b.manager.setForeground(true);
    final outcome = await a.manager
        .syncNow('B')
        .timeout(const Duration(seconds: 2));
    await settleNearby();
    expect(outcome?.error, isNull);
    expect(outcome, isNotNull);
    expect(
      a.engine.recordedAcks.where((r) => r.peer == 'C'),
      hasLength(1),
      reason: 'only the device the diver asked for',
    );
  });

  test('a row says Bluetooth is off only while the radio is wanted', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    a.auto = false;
    await a.manager.setForeground(true);
    hub.setAvailability('A', NearbyAvailability.bluetoothOff);
    await settleNearby();
    await a.manager.syncNow('B');
    expect(
      a.peers.errorOf((await a.peers.get('B'))!),
      NearbyPeerError.bluetoothOff,
    );

    hub.setAvailability('A', NearbyAvailability.ready);
    await settleNearby();
    expect(a.peers.errorOf((await a.peers.get('B'))!), isNull);
  });
}
