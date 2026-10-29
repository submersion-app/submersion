import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_card_bridge.dart';
import 'package:submersion/core/services/nearby/nearby_card_host.dart';

import '../../../support/in_memory_nearby_carrier.dart';
import '../../../support/memory_nearby_secrets.dart';
import '../../../support/nearby_link_harness.dart';

/// Card swaps over a carrier outside the link manager, as the Multipeer
/// carrier on Apple devices is (issue #3728). An in-memory carrier stands
/// in for Multipeer.
void main() {
  Uint8List bytesOf(String s) => Uint8List.fromList(utf8.encode(s));

  Future<(NearbyCardHost, List<NearbyCardEvent>)> phone(
    InMemoryNearbyHub mpc,
    String id,
    String name, {
    NearbyTestDevice? ble,
    DateTime Function()? now,
  }) async {
    final host = NearbyCardHost(
      name: name,
      card: () async => bytesOf('card of $name'),
      now: now,
    );
    addTearDown(host.dispose);
    final events = <NearbyCardEvent>[];
    host.events.listen(events.add);
    final bridge = NearbyCardBridge(
      carrier: mpc.join(id),
      host: host,
      identity: () async => nearbyTestIdentity(id),
      secrets: MemoryNearbySecrets(),
    );
    addTearDown(bridge.stop);
    if (ble != null) {
      await ble.manager.setForeground(true);
      await ble.manager.enterCardMode(host);
    }
    await bridge.start();
    return (host, events);
  }

  test('two phones see each other and swap over the bridge alone', () async {
    final mpc = InMemoryNearbyHub();
    final (hostA, eventsA) = await phone(mpc, 'A', 'Ann');
    final (_, eventsB) = await phone(mpc, 'B', 'Ben');
    await settleNearby();

    final ben = hostA.peers.singleWhere((p) => p.name == 'Ben');
    expect(ben.transportId, startsWith('mpc:'));
    unawaited(hostA.request(ben));
    await settleNearby();
    eventsB.whereType<CardRequested>().single.decide(true);
    await settleNearby();

    expect(
      utf8.decode(eventsA.whereType<CardReceived>().single.cardBytes),
      'card of Ben',
    );
    expect(
      utf8.decode(eventsB.whereType<CardReceived>().single.cardBytes),
      'card of Ann',
    );
    expect(mpc.openLinks, 0);
  });

  test('a diver seen over both carriers shows once, over Multipeer', () async {
    final mpc = InMemoryNearbyHub();
    final ble = InMemoryNearbyHub();
    final bleA = await joinNearbyTestDevice(ble, 'A');
    final bleB = await joinNearbyTestDevice(ble, 'B');
    bleA.auto = false;
    bleB.auto = false;
    final (hostA, _) = await phone(mpc, 'A', 'Ann', ble: bleA);
    await phone(mpc, 'B', 'Ben', ble: bleB);
    await bleA.manager.refresh();
    await bleB.manager.refresh();
    await settleNearby();

    final bens = hostA.peers.where((p) => p.name == 'Ben').toList();
    expect(bens, hasLength(1));
    expect(bens.single.transportId, startsWith('mpc:'));
  });

  test('a diver seen over both carriers stays listed while either sees '
      'them', () async {
    final mpc = InMemoryNearbyHub();
    final ble = InMemoryNearbyHub();
    final bleA = await joinNearbyTestDevice(ble, 'A');
    final bleB = await joinNearbyTestDevice(ble, 'B');
    bleA.auto = false;
    bleB.auto = false;
    var clock = DateTime(2026, 10, 28, 12);
    final (hostA, _) = await phone(
      mpc,
      'A',
      'Ann',
      ble: bleA,
      now: () => clock,
    );
    await phone(mpc, 'B', 'Ben', ble: bleB);
    await bleA.manager.refresh();
    await bleB.manager.refresh();
    await settleNearby();
    expect(hostA.peers.single.transportId, startsWith('mpc:'));

    // A minute on, Bluetooth still sees Ben, Multipeer has said nothing new.
    clock = clock.add(const Duration(minutes: 1));
    await bleA.manager.refresh();
    await settleNearby();
    expect(hostA.peers.map((p) => p.name), ['Ben']);
  });

  test('a dial that fails after connecting closes its link', () async {
    final mpc = InMemoryNearbyHub();
    final host = NearbyCardHost(name: 'Ann', card: () async => bytesOf('a'));
    addTearDown(host.dispose);
    final bridge = NearbyCardBridge(
      carrier: mpc.join('A'),
      host: host,
      // The identity cannot be read (a keychain error, say).
      identity: () async => throw StateError('no identity'),
      secrets: MemoryNearbySecrets(),
    );
    addTearDown(bridge.stop);
    await bridge.start();
    final other = mpc.join('B');
    other.incoming.listen((_) {});
    await other.startAdvertising();

    await host.request(
      const NearbyCardPeer(swapId: 'b', name: 'Ben', transportId: 'mpc:B'),
    );
    await settleNearby();

    expect(mpc.openLinks, 0);
  });
}
