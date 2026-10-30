import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_card_host.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_frame.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';

import '../../../support/in_memory_nearby_carrier.dart';
import '../../../support/memory_nearby_secrets.dart';
import '../../../support/nearby_link_harness.dart';
import '../../../support/nearby_session_harness.dart';

/// Card mode on the link manager (issue #3728): discovery, requests and the
/// swap itself between strangers' phones on their swap screens.
void main() {
  Uint8List bytesOf(String s) => Uint8List.fromList(utf8.encode(s));

  Future<(NearbyTestDevice, NearbyCardHost, List<NearbyCardEvent>)> onScreen(
    InMemoryNearbyHub hub,
    String id,
    String name, {
    Duration answerWindow = const Duration(seconds: 60),
    DateTime Function()? now,
  }) async {
    final device = await joinNearbyTestDevice(hub, id);
    device.auto = false;
    final host = NearbyCardHost(
      name: name,
      card: () async => bytesOf('card of $name'),
      answerWindow: answerWindow,
      now: now,
    );
    addTearDown(host.dispose);
    final events = <NearbyCardEvent>[];
    host.events.listen(events.add);
    await device.manager.setForeground(true);
    await device.manager.enterCardMode(host);
    return (device, host, events);
  }

  Future<void> discover(List<NearbyTestDevice> devices) async {
    for (final d in devices) {
      await d.manager.refresh();
    }
    await settleNearby();
  }

  List<String> namesSeen(NearbyCardHost host) =>
      host.peers.map((p) => p.name).toList()..sort();

  NearbyCardPeer peerNamed(NearbyCardHost host, String name) =>
      host.peers.firstWhere((p) => p.name == name);

  test('discovery lists the other diver and closes the link', () async {
    final hub = InMemoryNearbyHub();
    final (a, hostA, _) = await onScreen(hub, 'A', 'Ann');
    final (b, hostB, _) = await onScreen(hub, 'B', 'Ben');
    await discover([a, b]);
    expect(namesSeen(hostA), ['Ben']);
    expect(namesSeen(hostB), ['Ann']);
    expect(hub.openLinks, 0);
  });

  test('a device not on its swap screen is not listed', () async {
    final hub = InMemoryNearbyHub();
    final (a, hostA, _) = await onScreen(hub, 'A', 'Ann');
    final b = await joinNearbyTestDevice(hub, 'B');
    b.auto = true;
    await b.manager.setForeground(true);
    await b.carrier.startAdvertising();
    await discover([a]);
    expect(hostA.peers, isEmpty);
  });

  test('three divers are all listed and no link stays open', () async {
    final hub = InMemoryNearbyHub();
    final (a, hostA, _) = await onScreen(hub, 'A', 'Ann');
    final (b, _, _) = await onScreen(hub, 'B', 'Ben');
    final (c, _, _) = await onScreen(hub, 'C', 'Cat');
    await discover([a, b, c]);
    expect(namesSeen(hostA), ['Ben', 'Cat']);
    expect(hub.openLinks, 0);
  });

  test('a request asks the other diver; accepting swaps both cards', () async {
    final hub = InMemoryNearbyHub();
    final (a, hostA, eventsA) = await onScreen(hub, 'A', 'Ann');
    final (b, _, eventsB) = await onScreen(hub, 'B', 'Ben');
    await discover([a, b]);

    unawaited(hostA.request(peerNamed(hostA, 'Ben')));
    await settleNearby();
    final asked = eventsB.whereType<CardRequested>().single;
    expect(asked.from.name, 'Ann');
    asked.decide(true);
    await settleNearby();

    final gotA = eventsA.whereType<CardReceived>().single;
    final gotB = eventsB.whereType<CardReceived>().single;
    expect(utf8.decode(gotA.cardBytes), 'card of Ben');
    expect(utf8.decode(gotB.cardBytes), 'card of Ann');
    expect(hub.openLinks, 0);
  });

  test('declining tells the asker and sends no card', () async {
    final hub = InMemoryNearbyHub();
    final (a, hostA, eventsA) = await onScreen(hub, 'A', 'Ann');
    final (b, _, eventsB) = await onScreen(hub, 'B', 'Ben');
    await discover([a, b]);

    unawaited(hostA.request(peerNamed(hostA, 'Ben')));
    await settleNearby();
    eventsB.whereType<CardRequested>().single.decide(false);
    await settleNearby();

    expect(
      eventsA.whereType<CardSwapFailed>().single.reason,
      NearbyCardFailure.declined,
    );
    expect(eventsA.whereType<CardReceived>(), isEmpty);
    expect(eventsB.whereType<CardReceived>(), isEmpty);
  });

  test('no answer within the window times out', () async {
    final hub = InMemoryNearbyHub();
    const window = Duration(milliseconds: 150);
    final (a, hostA, eventsA) = await onScreen(
      hub,
      'A',
      'Ann',
      answerWindow: window,
    );
    final (b, _, eventsB) = await onScreen(
      hub,
      'B',
      'Ben',
      answerWindow: window,
    );
    await discover([a, b]);

    unawaited(hostA.request(peerNamed(hostA, 'Ben')));
    await settleNearby();
    expect(eventsB.whereType<CardRequested>(), hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await settleNearby();

    expect(
      eventsA.whereType<CardSwapFailed>().single.reason,
      NearbyCardFailure.timedOut,
    );
    expect(eventsB.whereType<CardReceived>(), isEmpty);
    // The asked diver's sheet is told to close.
    expect(eventsB.whereType<CardRequestExpired>(), hasLength(1));
  });

  test('both requesting at once makes one swap and one card each', () async {
    final hub = InMemoryNearbyHub();
    final (a, hostA, eventsA) = await onScreen(hub, 'A', 'Ann');
    final (b, hostB, eventsB) = await onScreen(hub, 'B', 'Ben');
    await discover([a, b]);

    unawaited(hostA.request(peerNamed(hostA, 'Ben')));
    unawaited(hostB.request(peerNamed(hostB, 'Ann')));
    await settleNearby();
    await settleNearby();

    expect(eventsA.whereType<CardRequested>(), isEmpty);
    expect(eventsB.whereType<CardRequested>(), isEmpty);
    expect(eventsA.whereType<CardReceived>(), hasLength(1));
    expect(eventsB.whereType<CardReceived>(), hasLength(1));
  });

  test('leaving card mode ends a waiting swap and refuses new ones', () async {
    final hub = InMemoryNearbyHub();
    var clock = DateTime(2026, 10, 28, 12);
    final (a, hostA, eventsA) = await onScreen(
      hub,
      'A',
      'Ann',
      now: () => clock,
    );
    final (b, hostB, _) = await onScreen(hub, 'B', 'Ben');
    await discover([a, b]);

    unawaited(hostA.request(peerNamed(hostA, 'Ben')));
    await settleNearby();
    await b.manager.leaveCardMode();
    await settleNearby();
    expect(
      eventsA.whereType<CardSwapFailed>().single.reason,
      NearbyCardFailure.lost,
    );
    expect(hub.openLinks, 0);

    // B is off its swap screen and its radio is off: A stops seeing it,
    // and after a while stops listing it.
    await hostB.dispose();
    await discover([a]);
    expect(hostA.peers.where((p) => p.name == 'Ben'), hasLength(1));
    clock = clock.add(const Duration(minutes: 1));
    expect(hostA.peers.where((p) => p.name == 'Ben'), isEmpty);
  });

  test('a request to a diver who left fails and frees the row', () async {
    final hub = InMemoryNearbyHub();
    final (a, hostA, eventsA) = await onScreen(hub, 'A', 'Ann');
    final (b, _, _) = await onScreen(hub, 'B', 'Ben');
    await discover([a, b]);
    final ben = peerNamed(hostA, 'Ben');

    await b.manager.leaveCardMode();
    await settleNearby();
    await hostA.request(ben);
    await settleNearby();

    expect(
      eventsA.whereType<CardSwapFailed>().single.reason,
      NearbyCardFailure.lost,
    );
  });

  test('a request with no way to dial times out', () async {
    final host = NearbyCardHost(
      name: 'Ann',
      card: () async => bytesOf('card'),
      answerWindow: const Duration(milliseconds: 100),
    );
    addTearDown(host.dispose);
    final events = <NearbyCardEvent>[];
    host.events.listen(events.add);
    await host.request(const NearbyCardPeer(swapId: 'x', name: 'Xan'));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(
      events.whereType<CardSwapFailed>().single.reason,
      NearbyCardFailure.timedOut,
    );
  });

  test('after a swap, the same diver asking again is asked again', () async {
    final hub = InMemoryNearbyHub();
    var clock = DateTime(2026, 10, 28, 12);
    final (a, hostA, _) = await onScreen(hub, 'A', 'Ann');
    final (b, hostB, eventsB) = await onScreen(
      hub,
      'B',
      'Ben',
      now: () => clock,
    );
    await discover([a, b]);
    unawaited(hostA.request(peerNamed(hostA, 'Ben')));
    await settleNearby();
    eventsB.whereType<CardRequested>().single.decide(true);
    await settleNearby();
    expect(eventsB.whereType<CardReceived>(), hasLength(1));

    clock = clock.add(const Duration(minutes: 1));
    unawaited(hostA.request(peerNamed(hostA, 'Ben')));
    await settleNearby();
    expect(eventsB.whereType<CardRequested>(), hasLength(2));
  });

  test('a buddy first met as a stranger is still listed on the swap '
      'screen', () async {
    final hub = InMemoryNearbyHub();
    // A syncs with its own paired laptop L, so it dials every Submersion
    // device it sees, and B (not paired) refuses it as a stranger. A can
    // only scan (as on Linux), so B can never list A by dialling it: only
    // A's own look at B can put Ben on A's list.
    final a = await joinNearbyTestDevice(hub, 'A', canAdvertise: false);
    final l = await joinNearbyTestDevice(hub, 'L');
    final b = await joinNearbyTestDevice(hub, 'B');
    await pairNearbyTestDevices(a, l);
    await foregroundNearbyTestDevices([a, b]);
    await b.carrier.startAdvertising();
    await a.manager.refresh();
    await settleNearby();

    final hostA = NearbyCardHost(name: 'Ann', card: () async => bytesOf('a'));
    final hostB = NearbyCardHost(name: 'Ben', card: () async => bytesOf('b'));
    addTearDown(hostA.dispose);
    addTearDown(hostB.dispose);
    await b.manager.enterCardMode(hostB);
    await a.manager.enterCardMode(hostA);
    await a.manager.refresh();
    await settleNearby();

    expect(hostA.peers.map((p) => p.name), contains('Ben'));
  });
  test(
    'a request whose session ends before the diver is heard fails',
    () async {
      final host = NearbyCardHost(
        name: 'Ann',
        card: () async => bytesOf('card'),
        step: const Duration(milliseconds: 100),
      );
      addTearDown(host.dispose);
      final events = <NearbyCardEvent>[];
      host.events.listen(events.add);
      host.attachCarrier('t:', (_) async {
        final (out, into) = await nearbyLink();
        // The other phone opens the session and then says nothing.
        unawaited(
          NearbySession(
            endpoint: into,
            identity: nearbySessionIdentity('P'),
            secrets: MemoryNearbySecrets(),
          ).accept(allowPairing: false, allowCard: true),
        );
        return NearbySession(
          endpoint: out,
          identity: nearbySessionIdentity('L'),
          secrets: MemoryNearbySecrets(),
        ).openCard();
      });

      await host.request(
        const NearbyCardPeer(swapId: 'ben', name: 'Ben', transportId: 't:1'),
      );
      await settleNearby();

      expect(
        events.whereType<CardSwapFailed>().single.reason,
        NearbyCardFailure.lost,
      );
    },
  );

  test('accepting after the asker has gone says the swap was lost', () async {
    final hub = InMemoryNearbyHub();
    final (a, hostA, _) = await onScreen(hub, 'A', 'Ann');
    final (b, _, eventsB) = await onScreen(hub, 'B', 'Ben');
    await discover([a, b]);

    unawaited(hostA.request(peerNamed(hostA, 'Ben')));
    await settleNearby();
    final asked = eventsB.whereType<CardRequested>().single;
    await hostA.dispose();
    await settleNearby();
    asked.decide(true);
    await settleNearby();

    expect(
      eventsB.whereType<CardSwapFailed>().single.reason,
      NearbyCardFailure.lost,
    );
  });

  test('a dial that fails is tried again soon, not minutes later', () async {
    var clock = DateTime(2026, 10, 28, 12);
    final host = NearbyCardHost(
      name: 'Ann',
      card: () async => bytesOf('card'),
      now: () => clock,
    );
    addTearDown(host.dispose);
    var dials = 0;
    host.attachCarrier('t:', (_) async {
      dials++;
      throw const NearbyConnectFailed('busy');
    });

    host.onSighting('t:1');
    await settleNearby();
    clock = clock.add(const Duration(seconds: 11));
    host.onSighting('t:1');
    await settleNearby();

    expect(dials, 2);
  });

  group('a nearby summary names a diver properly or not at all', () {
    Future<List<NearbyCardPeer>> seenWith(String name) async {
      final host = NearbyCardHost(
        name: 'Ann',
        card: () async => bytesOf('card'),
        step: const Duration(milliseconds: 200),
      );
      addTearDown(host.dispose);
      host.attachCarrier('t:', (_) async {
        final (out, into) = await nearbyLink();
        unawaited(() async {
          final incoming = await NearbySession(
            endpoint: into,
            identity: nearbySessionIdentity('P'),
            secrets: MemoryNearbySecrets(),
          ).accept(allowPairing: false, allowCard: true);
          final channel = (incoming as NearbyIncomingCard).channel;
          await channel.send(
            NearbyMessageType.cardSummary,
            bytesOf(jsonEncode({'s': 'peer', 'n': name})),
          );
        }());
        return NearbySession(
          endpoint: out,
          identity: nearbySessionIdentity('L'),
          secrets: MemoryNearbySecrets(),
        ).openCard();
      });
      host.onSighting('t:1');
      await settleNearby();
      return host.peers;
    }

    test('a blank name is not listed', () async {
      expect(await seenWith('   '), isEmpty);
    });

    test('a name is trimmed and kept to 200 characters', () async {
      final peers = await seenWith('  ${'x' * 5000}  ');
      expect(peers.single.name, 'x' * 200);
    });
  });
}
