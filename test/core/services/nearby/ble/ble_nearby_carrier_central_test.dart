import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/ble/ble_nearby_carrier.dart';
import 'package:submersion/core/services/nearby/ble/nearby_gatt.dart';

import '../../../../support/fake_ble_radio.dart';

/// An Apple central reading the peer's outbox (issue #4093). CoreBluetooth
/// reports read answers and notifications through one callback, so bytes
/// and doorbells must never share a characteristic.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const peer = 'aaaaaaaa-0000-4000-8000-000000000001';

  late FakeAppleCentral central;

  setUp(() {
    central = FakeAppleCentral()..serviceUuid = nearbyServiceUuid;
    useFakeBleRadio(central: central);
  });

  Future<void> until(bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('subscribes to the doorbell, never to the outbox it reads', () async {
    final carrier = BleNearbyCarrier(needsPermission: false);
    addTearDown(carrier.dispose);

    final end = await carrier.connect(peer);
    addTearDown(end.close);

    expect(central.subscribed, {nearbyDoorbellUuid});
  });

  test('a doorbell landing on an outstanding read costs no bytes', () async {
    final carrier = BleNearbyCarrier(needsPermission: false);
    addTearDown(carrier.dispose);
    final end = await carrier.connect(peer);
    addTearDown(end.close);
    final received = BytesBuilder();
    final sub = end.inbound.listen(received.add);
    addTearDown(sub.cancel);
    final bytes = Uint8List.fromList(const [10, 20, 30, 40]);

    // Hold the poll's read open, and ring while it is outstanding.
    central.holdReads = true;
    await until(() => central.outstandingReads == 1);
    expect(central.outstandingReads, 1);
    central.peerOutbox.add(bytes);
    central.peerRings(peer);
    central.releaseReads(peer);

    await until(() => received.length >= bytes.length);
    expect(received.takeBytes(), bytes);
  });

  test('an idle link only polls: a read answer does not start another '
      'read', () async {
    final carrier = BleNearbyCarrier(needsPermission: false);
    addTearDown(carrier.dispose);
    final end = await carrier.connect(peer);
    addTearDown(end.close);

    await Future<void>.delayed(const Duration(milliseconds: 600));

    expect(central.reads, lessThan(6), reason: 'a poll every 250 ms');
  });
}
