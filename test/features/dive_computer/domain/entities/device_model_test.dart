import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';

void main() {
  group('DeviceModel.fromDescriptor', () {
    test(
      'creates DeviceModel from Pigeon DeviceDescriptor with BLE and USB',
      () {
        final descriptor = pigeon.DeviceDescriptor(
          vendor: 'Shearwater',
          product: 'Perdix',
          model: 42,
          transports: [pigeon.TransportType.ble, pigeon.TransportType.usb],
        );

        final model = DeviceModel.fromDescriptor(descriptor);

        expect(model.id, 'Shearwater_Perdix_42');
        expect(model.manufacturer, 'Shearwater');
        expect(model.model, 'Perdix');
        expect(model.dcModel, 42);
        expect(model.supportsBle, isTrue);
        expect(model.supportsUsb, isTrue);
        expect(model.connectionTypes, [
          DeviceConnectionType.ble,
          DeviceConnectionType.usb,
        ]);
      },
    );

    test('maps serial transport to USB', () {
      final descriptor = pigeon.DeviceDescriptor(
        vendor: 'Suunto',
        product: 'Vyper',
        model: 10,
        transports: [pigeon.TransportType.serial],
      );

      final model = DeviceModel.fromDescriptor(descriptor);

      expect(model.supportsUsb, isTrue);
      expect(model.supportsBle, isFalse);
    });

    test('maps infrared transport', () {
      final descriptor = pigeon.DeviceDescriptor(
        vendor: 'Uwatec',
        product: 'Aladin',
        model: 5,
        transports: [pigeon.TransportType.infrared],
      );

      final model = DeviceModel.fromDescriptor(descriptor);

      expect(model.connectionTypes, contains(DeviceConnectionType.infrared));
    });

    test('handles empty transports list', () {
      final descriptor = pigeon.DeviceDescriptor(
        vendor: 'Test',
        product: 'Device',
        model: 0,
        transports: [],
      );

      final model = DeviceModel.fromDescriptor(descriptor);

      expect(model.connectionTypes, isEmpty);
      expect(model.supportsBle, isFalse);
      expect(model.supportsUsb, isFalse);
    });
  });

  group('DiscoveredDevice.fromPigeon', () {
    test(
      'creates DiscoveredDevice from Pigeon DiscoveredDevice with model',
      () {
        final pigeonDevice = pigeon.DiscoveredDevice(
          vendor: 'Shearwater',
          product: 'Perdix',
          model: 42,
          address: 'AA:BB:CC:DD:EE:FF',
          name: 'Perdix 12345',
          transport: pigeon.TransportType.ble,
        );

        final device = DiscoveredDevice.fromPigeon(pigeonDevice);

        expect(device.address, 'AA:BB:CC:DD:EE:FF');
        expect(device.name, 'Perdix 12345');
        expect(device.connectionType, DeviceConnectionType.ble);
        expect(device.isRecognized, isTrue);
        expect(device.recognizedModel?.manufacturer, 'Shearwater');
        expect(device.recognizedModel?.model, 'Perdix');
        expect(device.recognizedModel?.dcModel, 42);
      },
    );

    test('creates DiscoveredDevice without name', () {
      final pigeonDevice = pigeon.DiscoveredDevice(
        vendor: 'Mares',
        product: 'Puck Pro',
        model: 7,
        address: '11:22:33:44:55:66',
        transport: pigeon.TransportType.usb,
      );

      final device = DiscoveredDevice.fromPigeon(pigeonDevice);

      expect(device.name, 'Mares Puck Pro');
      expect(device.connectionType, DeviceConnectionType.usb);
    });

    test('maps transport types correctly', () {
      for (final entry in {
        pigeon.TransportType.ble: DeviceConnectionType.ble,
        pigeon.TransportType.usb: DeviceConnectionType.usb,
        pigeon.TransportType.serial: DeviceConnectionType.usb,
        pigeon.TransportType.infrared: DeviceConnectionType.infrared,
      }.entries) {
        final pigeonDevice = pigeon.DiscoveredDevice(
          vendor: 'Test',
          product: 'Device',
          model: 1,
          address: 'addr',
          transport: entry.key,
        );

        final device = DiscoveredDevice.fromPigeon(pigeonDevice);

        expect(
          device.connectionType,
          entry.value,
          reason: 'Transport ${entry.key} should map to ${entry.value}',
        );
      }
    });
  });

  group('DiscoveredDevice.toPigeon', () {
    test('round-trips through fromPigeon and toPigeon', () {
      final original = pigeon.DiscoveredDevice(
        vendor: 'Shearwater',
        product: 'Perdix',
        model: 42,
        address: 'AA:BB:CC:DD:EE:FF',
        name: 'Perdix 12345',
        transport: pigeon.TransportType.ble,
      );

      final appDevice = DiscoveredDevice.fromPigeon(original);
      final roundTripped = appDevice.toPigeon();

      expect(roundTripped.vendor, 'Shearwater');
      expect(roundTripped.product, 'Perdix');
      expect(roundTripped.model, 42);
      expect(roundTripped.address, 'AA:BB:CC:DD:EE:FF');
      expect(roundTripped.name, 'Perdix 12345');
      expect(roundTripped.transport, pigeon.TransportType.ble);
    });

    test('maps USB connection type back to USB transport', () {
      final device = DiscoveredDevice(
        id: 'test_usb',
        name: 'USB Device',
        connectionType: DeviceConnectionType.usb,
        address: '0001:0002',
        discoveredAt: DateTime(2024),
      );

      final pigeonDevice = device.toPigeon();

      expect(pigeonDevice.transport, pigeon.TransportType.usb);
    });

    test('uses fallback values when recognizedModel is null', () {
      final device = DiscoveredDevice(
        id: 'unknown_device',
        name: 'Unknown Device',
        connectionType: DeviceConnectionType.ble,
        address: 'XX:YY:ZZ',
        discoveredAt: DateTime(2024),
      );

      final pigeonDevice = device.toPigeon();

      expect(pigeonDevice.vendor, '');
      expect(pigeonDevice.product, 'Unknown Device');
      expect(pigeonDevice.model, 0);
    });
  });
}
