import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';

import '../../../support/in_memory_nearby_carrier.dart';
import '../../../support/nearby_link_harness.dart';

void main() {
  late InMemoryNearbyHub hub;

  setUp(() => hub = InMemoryNearbyHub());

  test('pairing mode dials no other device while a code is on screen, and '
      'dials again once the diver answers (issue #4154)', () async {
    final a = await joinNearbyTestDevice(hub, 'A');
    final b = await joinNearbyTestDevice(hub, 'B');
    final aOffers = <List<NearbyPairingHandle>>[];
    a.manager.pendingPairings.listen(aOffers.add);
    await foregroundNearbyTestDevices([a, b]);
    await a.manager.enterPairingMode();
    await b.manager.enterPairingMode();
    await settleNearby();
    expect(aOffers.last, hasLength(1));

    // A third device starts advertising while A and B compare codes.
    final c = hub.join('C');
    final dialledC = <String>[];
    c.incoming.listen((endpoint) {
      dialledC.add(endpoint.transportId);
      endpoint.close();
    });
    await c.startAdvertising();
    await a.manager.refresh();
    await settleNearby();
    expect(dialledC.where((id) => id == 'A'), isEmpty);

    await aOffers.last.single.reject();
    await settleNearby();
    expect(dialledC.where((id) => id == 'A'), isNotEmpty);
  });
}
