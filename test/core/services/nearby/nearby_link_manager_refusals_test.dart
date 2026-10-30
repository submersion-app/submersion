import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_frame.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';
import 'package:submersion/core/services/nearby/nearby_sync_protocol.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';

import '../../../helpers/global_test_defaults.dart';
import '../../../support/in_memory_nearby_carrier.dart';
import '../../../support/nearby_link_harness.dart';

/// What refusals between paired devices leave on their rows, what they do
/// to the next connection, and when no session may run at all (issue
/// #3731).
void main() {
  late InMemoryNearbyHub hub;

  setUp(() => hub = InMemoryNearbyHub());

  Future<NearbyTestDevice> device(String id, {bool canAdvertise = true}) =>
      joinNearbyTestDevice(hub, id, canAdvertise: canAdvertise);

  /// Counts the links [ds] accept: every connection in the room.
  int Function() countLinks(List<NearbyTestDevice> ds) {
    var count = 0;
    for (final d in ds) {
      final sub = d.carrier.incoming.listen((_) => count++);
      addTearDown(sub.cancel);
    }
    return () => count;
  }

  test('a paired device that moved to another library is shown as such on '
      'both devices, the one dialled as well as the one dialling', () async {
    final laptop = await device('A');
    // Scan-only, so it always dials and the laptop always answers.
    final phone = await device('B', canAdvertise: false);
    await pairNearbyTestDevices(laptop, phone);
    // The phone replaced its library and joined another one.
    phone.engine.self = nearbyTestIdentity('B', epoch: 'epoch-2');
    await foregroundNearbyTestDevices([laptop, phone]);

    expect(
      laptop.peers.errorOf((await laptop.peers.get('B'))!),
      NearbyPeerError.differentLibrary,
    );
    expect(
      phone.peers.errorOf((await phone.peers.get('A'))!),
      NearbyPeerError.differentLibrary,
    );
    expect(laptop.engine.recordedApplied, isEmpty);
  });

  test('a paired device that keeps refusing is still seen, so its row '
      'goes on holding tombstones back', () async {
    final laptop = await device('A');
    final phone = await device('B', canAdvertise: false);
    await pairNearbyTestDevices(laptop, phone);
    phone.engine.self = nearbyTestIdentity('B', epoch: 'epoch-2');
    await foregroundNearbyTestDevices([laptop, phone]);

    expect((await laptop.peers.get('B'))!.lastSeenAt, isNotNull);
    expect((await phone.peers.get('A'))!.lastSeenAt, isNotNull);
  });

  test('a known peer refusing for a reason of its own reads as unreachable, '
      'not as a clean sync', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    await foregroundNearbyTestDevices([a, b]);
    expect(a.engine.recordedAcks, hasLength(1), reason: 'met once');
    // B answers every hello with a refusal that names no reason.
    await b.manager.dispose();
    await b.carrier.startAdvertising();
    final refusing = b.carrier.incoming.listen((endpoint) {
      unawaited(
        endpoint.send(
          FrameEncoder.encode(
            NearbyMessageType.error,
            Uint8List.fromList([NearbyErrorCode.protocol.index]),
          ),
        ),
      );
    });
    addTearDown(refusing.cancel);

    final outcome = await a.manager.syncNow('B');
    expect(outcome?.error, NearbyPeerError.unreachable);
    expect(
      a.peers.errorOf((await a.peers.get('B'))!),
      NearbyPeerError.unreachable,
    );
  });

  test('a scan-only device keeps trying a device that was not in pairing '
      'mode yet', () async {
    final laptop = await device('L', canAdvertise: false);
    final phone = await device('P');
    final tablet = await device('T');
    // The phone's other pairing keeps its radio on before its pairing page
    // opens, so the laptop finds it too early.
    await pairNearbyTestDevices(phone, tablet);
    final offers = <List<NearbyPairingHandle>>[];
    laptop.manager.pendingPairings.listen(offers.add);
    await phone.manager.setForeground(true);
    await laptop.manager.setForeground(true);
    await laptop.manager.enterPairingMode();
    await settleNearby();
    expect(offers, isEmpty, reason: 'the phone refused: not pairing yet');

    await phone.manager.enterPairingMode();
    await settleNearby();
    expect(offers.last.single.peerName, 'Device P');
  });

  test('a refusing peer waits out the cooldown like a synced one', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    b.engine.self = nearbyTestIdentity('B', epoch: 'epoch-2');
    final links = countLinks([a, b]);
    await foregroundNearbyTestDevices([a, b]);
    final first = links();
    expect(first, greaterThan(0));

    for (var i = 0; i < 3; i++) {
      await a.manager.refresh();
      await b.manager.refresh();
      await settleNearby();
    }
    expect(links(), first, reason: 'no redial inside the cooldown');

    // Past the cooldown it tries again: the diver may have fixed it.
    a.now = a.now.add(const Duration(minutes: 11));
    await a.manager.refresh();
    await settleNearby();
    expect(links(), greaterThan(first));
  });

  test('while the sample logbook is open, a peer that connects runs no '
      'session', () async {
    final a = await device('A');
    final b = await device('B');
    await pairNearbyTestDevices(a, b);
    await a.manager.setForeground(true);
    // Entering demo mode closes the gate before the app restarts, and
    // nothing turns the radio off in between.
    DemoModeGate.instance.debugActive = true;
    addTearDown(applyGlobalTestDefaults);

    try {
      final endpoint = await b.carrier.connect('A');
      final channel = await NearbySession(
        endpoint: endpoint,
        identity: b.engine.self,
        secrets: b.secrets,
      ).openSync();
      await NearbySyncProtocol(
        channel: channel,
        engine: b.engine,
        peers: b.peers,
        tempDir: () async => b.temp,
      ).run();
      await channel.close();
    } on Object {
      // Turned away: what the gate is for.
    }
    await settleNearby();
    expect(a.engine.recordedApplied, isEmpty);
    expect((await a.peers.get('B'))!.lastSyncedAt, isNull);
  });
}
