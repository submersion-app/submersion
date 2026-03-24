import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';

/// Tests for serial/USB transport handling relevant to the Cressi Leonardo
/// connectivity fix. Devices like the Cressi Leonardo appear as USB but
/// communicate via serial protocol. The native layer handles the transport
/// override, but the Dart layer must correctly map connection types.
void main() {
  group('serial-over-USB device transport mapping', () {
    test('serial transport from pigeon maps to USB connection type', () {
      // Cressi Leonardo reports serial transport from libdivecomputer.
      // The app maps this to USB connection type for the user.
      final descriptor = pigeon.DeviceDescriptor(
        vendor: 'Cressi',
        product: 'Leonardo',
        model: 18,
        transports: [pigeon.TransportType.serial],
      );

      final model = DeviceModel.fromDescriptor(descriptor);

      expect(model.supportsUsb, isTrue);
      expect(model.supportsBle, isFalse);
      expect(model.connectionTypes, [DeviceConnectionType.usb]);
    });

    test('USB connection type converts back to USB pigeon transport', () {
      // When the user selects a serial device shown as USB, toPigeon()
      // sends TransportType.usb. The native layer then overrides to
      // serial based on the device descriptor.
      final device = DiscoveredDevice(
        id: 'cressi_leonardo_18',
        name: 'Cressi Leonardo',
        connectionType: DeviceConnectionType.usb,
        address: 'Cressi_Leonardo',
        recognizedModel: const DeviceModel(
          id: 'Cressi_Leonardo_18',
          manufacturer: 'Cressi',
          model: 'Leonardo',
          connectionTypes: [DeviceConnectionType.usb],
          dcModel: 18,
        ),
        discoveredAt: DateTime(2026),
      );

      final pigeonDevice = device.toPigeon();

      expect(pigeonDevice.transport, pigeon.TransportType.usb);
      expect(pigeonDevice.vendor, 'Cressi');
      expect(pigeonDevice.product, 'Leonardo');
      expect(pigeonDevice.model, 18);
    });

    test('manual model selection uses model name as address', () {
      // When a user manually selects a model (no scan), the address
      // is not a COM port or /dev/ path. The native layer should
      // enumerate ports and try each one.
      final device = DiscoveredDevice(
        id: 'manual_cressi_leonardo',
        name: 'Cressi Leonardo',
        connectionType: DeviceConnectionType.usb,
        address: 'Cressi_Leonardo',
        recognizedModel: const DeviceModel(
          id: 'Cressi_Leonardo_18',
          manufacturer: 'Cressi',
          model: 'Leonardo',
          connectionTypes: [DeviceConnectionType.usb],
          dcModel: 18,
        ),
        discoveredAt: DateTime(2026),
      );

      final pigeonDevice = device.toPigeon();

      // Address is not a COM port or /dev/ path, so native will
      // auto-detect the serial port.
      expect(pigeonDevice.address, 'Cressi_Leonardo');
      expect(pigeonDevice.address.startsWith('COM'), isFalse);
      expect(pigeonDevice.address.startsWith('/dev/'), isFalse);
    });

    test('discovered serial device with COM port preserves address', () {
      // When a device is discovered via serial scan, the address is
      // a COM port. This should be preserved through the round-trip.
      final pigeonDiscovered = pigeon.DiscoveredDevice(
        vendor: 'Cressi',
        product: 'Leonardo',
        model: 18,
        address: 'COM3',
        name: 'Cressi Leonardo',
        transport: pigeon.TransportType.serial,
      );

      final appDevice = DiscoveredDevice.fromPigeon(pigeonDiscovered);
      final roundTripped = appDevice.toPigeon();

      expect(roundTripped.address, 'COM3');
      expect(roundTripped.vendor, 'Cressi');
      expect(roundTripped.product, 'Leonardo');
      expect(roundTripped.model, 18);
    });

    test('discovered serial device with /dev/ path preserves address', () {
      final pigeonDiscovered = pigeon.DiscoveredDevice(
        vendor: 'Cressi',
        product: 'Leonardo',
        model: 18,
        address: '/dev/ttyUSB0',
        name: 'Cressi Leonardo',
        transport: pigeon.TransportType.serial,
      );

      final appDevice = DiscoveredDevice.fromPigeon(pigeonDiscovered);
      final roundTripped = appDevice.toPigeon();

      expect(roundTripped.address, '/dev/ttyUSB0');
    });
  });
}
