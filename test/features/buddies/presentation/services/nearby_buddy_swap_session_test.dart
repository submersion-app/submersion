import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/multipeer/multipeer_nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_card_host.dart';
import 'package:submersion/features/buddies/data/services/buddy_card_nfc.dart';
import 'package:submersion/features/buddies/data/services/card_emulation_service.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/presentation/services/buddy_swap_session.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';

import '../../../../helpers/fake_nfc.dart';
import '../../../../helpers/global_test_defaults.dart';
import '../../../../support/in_memory_nearby_carrier.dart';
import '../../../../support/memory_nearby_secrets.dart';
import '../../../../support/nearby_link_harness.dart';

class _FakeEmulation implements CardEmulation {
  Uint8List? presenting;
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<void> start(Uint8List ndefMessage) async => presenting = ndefMessage;
  @override
  Future<void> stop() async => presenting = null;
}

/// The swap screen's session (issue #3728) stopping while it is still
/// starting, as when the screen closes or the app leaves the foreground
/// right after it opened.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a stop during start leaves nothing running', () async {
    final hub = InMemoryNearbyHub();
    final a = await joinNearbyTestDevice(hub, 'A');
    final b = await joinNearbyTestDevice(hub, 'B');
    a.auto = false;
    b.auto = false;
    await foregroundNearbyTestDevices([a, b]);
    final emulation = _FakeEmulation();
    final session = NearbyBuddySwapSession(
      card: const BuddyCard(id: 'a', name: 'Ann'),
      manager: a.manager,
      identity: () async => nearbyTestIdentity('A'),
      secrets: MemoryNearbySecrets(),
      nfc: BuddyCardNfc(tags: FakeNfcTagService(), emulation: emulation),
    );

    final starting = session.start();
    await session.stop();
    await starting;
    await settleNearby();

    expect(emulation.presenting, isNull, reason: 'no tag left presented');
    // A is not answering card sessions: B on its swap screen lists nobody.
    final hostB = NearbyCardHost(name: 'Ben', card: () async => Uint8List(1));
    addTearDown(hostB.dispose);
    await b.manager.enterCardMode(hostB);
    await b.manager.refresh();
    await settleNearby();
    expect(hostB.peers, isEmpty);
  });

  test('a start after a stop works again', () async {
    final hub = InMemoryNearbyHub();
    final a = await joinNearbyTestDevice(hub, 'A');
    a.auto = false;
    await foregroundNearbyTestDevices([a]);
    final emulation = _FakeEmulation();
    final session = NearbyBuddySwapSession(
      card: const BuddyCard(id: 'a', name: 'Ann'),
      manager: a.manager,
      identity: () async => nearbyTestIdentity('A'),
      secrets: MemoryNearbySecrets(),
      nfc: BuddyCardNfc(tags: FakeNfcTagService(), emulation: emulation),
    );
    await session.start();
    await session.stop();
    await session.start();
    expect(emulation.presenting, isNotNull);
    await session.stop();
    expect(emulation.presenting, isNull);
  });

  test('in demo mode nothing starts: no radio, no tag', () async {
    DemoModeGate.instance.debugActive = true;
    addTearDown(applyGlobalTestDefaults);
    final hub = InMemoryNearbyHub();
    final a = await joinNearbyTestDevice(hub, 'A');
    a.auto = false;
    await foregroundNearbyTestDevices([a]);
    final emulation = _FakeEmulation();
    final session = NearbyBuddySwapSession(
      card: const BuddyCard(id: 'a', name: 'Ann'),
      manager: a.manager,
      identity: () async => nearbyTestIdentity('A'),
      secrets: MemoryNearbySecrets(),
      nfc: BuddyCardNfc(tags: FakeNfcTagService(), emulation: emulation),
    );
    addTearDown(session.stop);

    expect(await session.start(), NearbyAvailability.unsupported);
    expect(emulation.presenting, isNull);
    expect(session.peers, isEmpty);
  });

  test('a Multipeer start that fails partway is still stopped', () async {
    const channel = MethodChannel('app.submersion/multipeer-test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add('${call.method} ${call.arguments}');
      if (call.method == 'isSupported') return true;
      if (call.method == 'advertise' && call.arguments == true) {
        throw PlatformException(code: 'failed');
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final multipeer = MultipeerNearbyCarrier(channel: channel);
    addTearDown(multipeer.dispose);

    final hub = InMemoryNearbyHub();
    final a = await joinNearbyTestDevice(hub, 'A');
    a.auto = false;
    await foregroundNearbyTestDevices([a]);
    final session = NearbyBuddySwapSession(
      card: const BuddyCard(id: 'a', name: 'Ann'),
      manager: a.manager,
      identity: () async => nearbyTestIdentity('A'),
      secrets: MemoryNearbySecrets(),
      nfc: BuddyCardNfc(tags: FakeNfcTagService(), emulation: _FakeEmulation()),
      multipeer: multipeer,
    );

    await expectLater(session.start(), throwsA(isA<PlatformException>()));
    await session.stop();
    // The bridge the failed start opened is closed: browsing and
    // advertising are turned off again.
    expect(calls, contains('advertise false'));
  });
}
