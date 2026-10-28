import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/ble/ble_nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:universal_ble/universal_ble.dart';

/// The carrier touches Bluetooth only once the link asks whether it is
/// available (issue #3731): never at launch, where it would show the
/// permission prompt to every diver and, on Linux without BlueZ, raise an
/// error universal_ble leaves uncaught.
void main() {
  test('building the carrier and following its availability touches no '
      'Bluetooth', () async {
    var reads = 0;
    var follows = 0;
    final carrier = BleNearbyCarrier(
      needsPermission: false,
      readAvailability: () async {
        reads++;
        return AvailabilityState.poweredOn;
      },
      availabilityUpdates: () {
        follows++;
        return const Stream.empty();
      },
    );
    final sub = carrier.availability.listen((_) {});
    addTearDown(sub.cancel);
    await Future<void>.delayed(Duration.zero);
    expect(reads, 0);
    expect(follows, 0);

    expect(await carrier.checkAvailability(), NearbyAvailability.ready);
    expect(follows, 1, reason: 'follows changes once Bluetooth answered');
  });

  test('availability changes reach the link after the first check', () async {
    final updates = StreamController<AvailabilityState>.broadcast();
    addTearDown(updates.close);
    final carrier = BleNearbyCarrier(
      needsPermission: false,
      readAvailability: () async => AvailabilityState.poweredOn,
      availabilityUpdates: () => updates.stream,
    );
    final seen = <NearbyAvailability>[];
    final sub = carrier.availability.listen(seen.add);
    addTearDown(sub.cancel);
    await carrier.checkAvailability();
    updates.add(AvailabilityState.poweredOff);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [NearbyAvailability.bluetoothOff]);
  });

  test(
    'a disposed carrier stops following Bluetooth and ends its '
    'streams, so a provider-scope restart leaves no listener behind',
    () async {
      final updates = StreamController<AvailabilityState>.broadcast();
      addTearDown(updates.close);
      final carrier = BleNearbyCarrier(
        needsPermission: false,
        readAvailability: () async => AvailabilityState.poweredOn,
        availabilityUpdates: () => updates.stream,
      );
      await carrier.checkAvailability();
      expect(updates.hasListener, isTrue);
      final ended = Completer<void>();
      carrier.availability.listen((_) {}, onDone: ended.complete);

      await carrier.dispose();
      expect(updates.hasListener, isFalse);
      await ended.future;
      updates.add(AvailabilityState.poweredOff); // nothing left to reach
    },
  );

  test('a Bluetooth stack that fails and leaves a stray error behind reads '
      'as unsupported, with nothing uncaught', () async {
    final carrier = BleNearbyCarrier(
      needsPermission: false,
      readAvailability: () async {
        // What universal_ble 3.1.0 does on Linux without BlueZ: it fails a
        // completer nobody listens to, then throws.
        Completer<void>().completeError(StateError('org.bluez unknown'));
        throw StateError('org.bluez unknown');
      },
      availabilityUpdates: () => const Stream.empty(),
    );
    expect(await carrier.checkAvailability(), NearbyAvailability.unsupported);
    await Future<void>.delayed(Duration.zero);
  });
}
