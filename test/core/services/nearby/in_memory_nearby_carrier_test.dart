import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';

import '../../../support/in_memory_nearby_carrier.dart';

Uint8List _b(List<int> v) => Uint8List.fromList(v);

void main() {
  late InMemoryNearbyHub hub;

  setUp(() => hub = InMemoryNearbyHub());

  test('a scanning carrier sees an advertising carrier', () async {
    final phone = hub.join('phone');
    final laptop = hub.join('laptop');
    final sightings = <NearbyPeerSighting>[];
    laptop.sightings.listen(sightings.add);
    await phone.startAdvertising();
    await laptop.startScanning();
    await pumpEventQueue();
    expect(sightings.map((s) => s.transportId), ['phone']);
  });

  test('an advertiser that starts after the scan is still seen', () async {
    final phone = hub.join('phone');
    final laptop = hub.join('laptop');
    final sightings = <NearbyPeerSighting>[];
    laptop.sightings.listen(sightings.add);
    await laptop.startScanning();
    await phone.startAdvertising();
    await pumpEventQueue();
    expect(sightings.map((s) => s.transportId), ['phone']);
  });

  test('a carrier never sights itself', () async {
    final phone = hub.join('phone');
    final sightings = <NearbyPeerSighting>[];
    phone.sightings.listen(sightings.add);
    await phone.startAdvertising();
    await phone.startScanning();
    await pumpEventQueue();
    expect(sightings, isEmpty);
  });

  test('connect yields two endpoints whose bytes cross both ways', () async {
    final phone = hub.join('phone');
    final laptop = hub.join('laptop');
    await phone.startAdvertising();
    final incoming = phone.incoming.first;
    final out = await laptop.connect('phone');
    final into = await incoming;

    expect(out.isInitiator, isTrue);
    expect(out.transportId, 'phone');
    expect(into.isInitiator, isFalse);
    expect(into.transportId, 'laptop');

    final atPhone = <int>[];
    final atLaptop = <int>[];
    into.inbound.listen(atPhone.addAll);
    out.inbound.listen(atLaptop.addAll);
    await out.send(_b([1, 2]));
    await into.send(_b([3]));
    await pumpEventQueue();
    expect(atPhone, [1, 2]);
    expect(atLaptop, [3]);
  });

  test('a scan-only carrier never appears as a sighting', () async {
    final linux = hub.join('linux', canAdvertise: false);
    final phone = hub.join('phone');
    final sightings = <NearbyPeerSighting>[];
    phone.sightings.listen(sightings.add);
    expect(linux.canAdvertise, isFalse);
    await expectLater(linux.startAdvertising(), throwsUnsupportedError);
    await phone.startScanning();
    await pumpEventQueue();
    expect(sightings, isEmpty);
  });

  test('connect to a device that is not advertising fails', () async {
    hub.join('phone');
    final laptop = hub.join('laptop');
    await expectLater(
      laptop.connect('phone'),
      throwsA(isA<NearbyConnectFailed>()),
    );
  });

  test('cutAfterBytes closes both endpoints', () async {
    final phone = hub.join('phone');
    final laptop = hub.join('laptop');
    await phone.startAdvertising();
    final incoming = phone.incoming.first;
    final out = await laptop.connect('phone');
    final into = await incoming;
    hub.cutAfterBytes('phone', 3);

    final atPhone = <int>[];
    final phoneDone = Completer<void>();
    final laptopDone = Completer<void>();
    into.inbound.listen(atPhone.addAll, onDone: phoneDone.complete);
    out.inbound.listen((_) {}, onDone: laptopDone.complete);
    await out.send(_b([1, 2]));
    await out.send(_b([3, 4]));
    await phoneDone.future;
    await laptopDone.future;
    // The second send would have crossed the budget, so none of it arrived.
    expect(atPhone, [1, 2]);
    await expectLater(out.send(_b([5])), throwsA(isA<NearbyLinkClosed>()));
  });

  test('closing one endpoint ends the other', () async {
    final phone = hub.join('phone');
    final laptop = hub.join('laptop');
    await phone.startAdvertising();
    final incoming = phone.incoming.first;
    final out = await laptop.connect('phone');
    final into = await incoming;
    final done = Completer<void>();
    into.inbound.listen((_) {}, onDone: done.complete);
    await out.close();
    await done.future;
  });

  test('availability reports what the hub sets', () async {
    final phone = hub.join('phone');
    final states = <NearbyAvailability>[];
    phone.availability.listen(states.add);
    hub.setAvailability('phone', NearbyAvailability.bluetoothOff);
    await pumpEventQueue();
    expect(states, [NearbyAvailability.bluetoothOff]);
  });
}
