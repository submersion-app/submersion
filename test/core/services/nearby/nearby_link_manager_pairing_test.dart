import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';

import '../../../support/in_memory_nearby_carrier.dart';
import '../../../support/nearby_link_harness.dart';

void main() {
  late InMemoryNearbyHub hub;

  setUp(() => hub = InMemoryNearbyHub());

  /// A and B in pairing mode with a code on both screens; returns them and
  /// their offers.
  Future<(NearbyTestDevice, NearbyTestDevice, List<List<NearbyPairingHandle>>)>
  codesShowing() async {
    final a = await joinNearbyTestDevice(hub, 'A');
    final b = await joinNearbyTestDevice(hub, 'B');
    final aOffers = <List<NearbyPairingHandle>>[];
    a.manager.pendingPairings.listen(aOffers.add);
    await foregroundNearbyTestDevices([a, b]);
    await a.manager.enterPairingMode();
    await b.manager.enterPairingMode();
    await settleNearby();
    expect(aOffers.last, hasLength(1));
    return (a, b, aOffers);
  }

  /// A third device advertising from now on; returns who dialled it.
  Future<List<String>> thirdDevice() async {
    final c = hub.join('C');
    final dialled = <String>[];
    c.incoming.listen((NearbyEndpoint endpoint) {
      dialled.add(endpoint.transportId);
      endpoint.close();
    });
    await c.startAdvertising();
    return dialled;
  }

  test('a code left on screen holds dialling back only for the pause, '
      'since a card whose peer left stays up', () async {
    final (a, _, _) = await codesShowing();
    final dialledC = await thirdDevice();
    a.now = a.now.add(a.manager.pairingDialPause);
    await a.manager.refresh();
    await settleNearby();
    expect(dialledC.where((id) => id == 'A'), isNotEmpty);
  });

  test('a confirm that fails lets dialling resume', () async {
    final (a, b, aOffers) = await codesShowing();
    final dialledC = await thirdDevice();
    final confirm = aOffers.last.single.confirm();
    await b.manager.currentPairings.single.reject();
    await expectLater(confirm, throwsA(isA<NearbyPairingRejected>()));
    await settleNearby();
    expect(dialledC.where((id) => id == 'A'), isNotEmpty);
  });

  test('pairing mode dials no other device while a code is on screen, and '
      'dials again once the diver answers (issue #4154)', () async {
    final (a, _, aOffers) = await codesShowing();
    // A third device starts advertising while A and B compare codes.
    final dialledC = await thirdDevice();
    await a.manager.refresh();
    await settleNearby();
    expect(dialledC.where((id) => id == 'A'), isEmpty);

    await aOffers.last.single.reject();
    await settleNearby();
    expect(dialledC.where((id) => id == 'A'), isNotEmpty);
  });
}
