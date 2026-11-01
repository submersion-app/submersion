import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/ble/ble_nearby_carrier.dart';
import 'package:submersion/core/services/nearby/ble/nearby_gatt.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../../../support/fake_ble_radio.dart';

/// Hosting the nearby service on an Apple radio (issue #4093). CoreBluetooth
/// drops every command sent before its manager reports power-on, and the
/// plugin creates that manager in the same call as the first command.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApplePeripheralManager peripheral;
  late StreamController<AvailabilityState> bluetooth;

  BleNearbyCarrier newCarrier({
    Duration patience = const Duration(seconds: 5),
  }) {
    final carrier = BleNearbyCarrier(
      canAdvertise: true,
      needsPermission: false,
      readAvailability: () async => AvailabilityState.poweredOn,
      availabilityUpdates: () => bluetooth.stream,
      peripheralPoll: const Duration(milliseconds: 1),
      peripheralPatience: patience,
    );
    addTearDown(carrier.dispose);
    return carrier;
  }

  setUp(() {
    peripheral = FakeApplePeripheralManager();
    useFakeBleRadio(peripheral: peripheral);
    bluetooth = StreamController<AvailabilityState>.broadcast();
    addTearDown(bluetooth.close);
  });

  test('waits for power-on before hosting or advertising', () async {
    final carrier = newCarrier();
    var started = false;
    final hosting = carrier.startAdvertising().then((_) => started = true);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(started, isFalse);
    expect(peripheral.registry, isEmpty, reason: 'nothing sent yet');

    peripheral.powerOn();
    await hosting;

    expect(peripheral.database, hasLength(1));
    expect(peripheral.hostedServiceUuid, nearbyServiceUuid);
    expect(peripheral.advertising, isTrue);
  });

  test('a manager that never powers on fails instead of waiting for ever, '
      'with nothing sent that the plugin would remember', () async {
    final carrier = newCarrier(patience: const Duration(milliseconds: 20));

    await expectLater(carrier.startAdvertising(), throwsA(anything));
    expect(peripheral.registry, isEmpty);
    expect(peripheral.advertising, isFalse);

    // Powered on by the next refresh, the same carrier hosts normally.
    peripheral.powerOn();
    await carrier.startAdvertising();
    expect(peripheral.database, hasLength(1));
    expect(peripheral.advertising, isTrue);
  });

  test('advertising again does not add the service again', () async {
    peripheral.powerOn();
    final carrier = newCarrier();
    await carrier.startAdvertising();
    await carrier.startAdvertising();
    expect(peripheral.database, hasLength(1));
  });

  test('a new carrier after a provider-scope restart does not host the '
      'service twice', () async {
    peripheral.powerOn();
    final first = newCarrier();
    await first.startAdvertising();
    await first.dispose();

    await newCarrier().startAdvertising();
    expect(peripheral.database, hasLength(1));
  });

  test('Bluetooth turned off and on hosts the service again, though the '
      'plugin still lists it', () async {
    peripheral.powerOn();
    final carrier = newCarrier();
    await carrier.checkAvailability();
    await carrier.startAdvertising();

    peripheral.bluetoothOff();
    bluetooth.add(AvailabilityState.poweredOff);
    await Future<void>.delayed(Duration.zero);
    expect(peripheral.database, isEmpty);
    expect(peripheral.registry, isNotEmpty, reason: 'the stale list');

    peripheral.powerOn();
    bluetooth.add(AvailabilityState.poweredOn);
    await Future<void>.delayed(Duration.zero);
    await carrier.startAdvertising();

    expect(peripheral.database, hasLength(1));
    expect(peripheral.advertising, isTrue);
  });

  test('Bluetooth going off as the add completes still hosts the service '
      'again', () async {
    peripheral.powerOn();
    final carrier = newCarrier();
    await carrier.checkAvailability();
    peripheral.afterAdd = () async {
      peripheral
        ..afterAdd = null
        ..bluetoothOff()
        ..powerOn();
      bluetooth.add(AvailabilityState.poweredOff);
      await Future<void>.delayed(Duration.zero);
    };

    await carrier.startAdvertising();
    expect(peripheral.database, isEmpty);

    await carrier.startAdvertising();
    expect(peripheral.database, hasLength(1));
  });

  test('a new carrier does not believe a list its predecessor learned was '
      'stale', () async {
    peripheral.powerOn();
    final first = newCarrier();
    await first.checkAvailability();
    await first.startAdvertising();
    peripheral.bluetoothOff();
    bluetooth.add(AvailabilityState.poweredOff);
    await Future<void>.delayed(Duration.zero);
    await first.dispose();

    peripheral.powerOn();
    await newCarrier().startAdvertising();
    expect(peripheral.database, hasLength(1));
  });

  test('a failed add is tried again: the plugin lists the service though '
      'it was never hosted', () async {
    peripheral
      ..powerOn()
      ..failNextAdd = true;
    final carrier = newCarrier();

    await expectLater(carrier.startAdvertising(), throwsA(anything));
    expect(peripheral.registry, isNotEmpty, reason: 'the stale list');

    await carrier.startAdvertising();
    expect(peripheral.database, hasLength(1));
    expect(peripheral.advertising, isTrue);
  });

  group('the doorbell', () {
    test(
      'has its own characteristic: Apple reports a read answer and a '
      'notification through one callback, so the outbox only reads',
      () async {
        peripheral.powerOn();
        await newCarrier().startAdvertising();

        expect(peripheral.propertiesOf(nearbyOutboxUuid), [
          CharacteristicProperty.read,
        ]);
        expect(peripheral.propertiesOf(nearbyDoorbellUuid), [
          CharacteristicProperty.notify,
        ]);
      },
    );

    test('a central subscribing to it opens an endpoint, and what is sent '
        'to that central rings it', () async {
      peripheral.powerOn();
      final carrier = newCarrier();
      await carrier.startAdvertising();
      final opened = carrier.incoming.first;

      peripheral.subscribe('central-1', nearbyDoorbellUuid);
      final end = await opened.timeout(const Duration(seconds: 5));
      unawaited(end.send(Uint8List.fromList(const [7, 8, 9])));
      await Future<void>.delayed(Duration.zero);

      expect(peripheral.rungCharacteristics, [nearbyDoorbellUuid]);
    });
  });
}
