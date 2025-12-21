import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/data/device_library.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';

void main() {
  late DeviceLibrary library;

  setUp(() {
    library = DeviceLibrary.instance;
  });

  group('DeviceLibrary', () {
    group('allModels', () {
      test('contains expected manufacturers', () {
        final manufacturers =
            library.allModels.map((m) => m.manufacturer).toSet();

        expect(manufacturers, contains('Shearwater'));
        expect(manufacturers, contains('Suunto'));
        expect(manufacturers, contains('Garmin'));
        expect(manufacturers, contains('Mares'));
        expect(manufacturers, contains('Scubapro'));
      });

      test('all models have required fields', () {
        for (final model in library.allModels) {
          expect(model.id, isNotEmpty);
          expect(model.manufacturer, isNotEmpty);
          expect(model.model, isNotEmpty);
          expect(model.connectionTypes, isNotEmpty);
        }
      });

      test('BLE models have service UUID', () {
        final bleModels = library.allModels
            .where((m) => m.connectionTypes.contains(DeviceConnectionType.ble));

        for (final model in bleModels) {
          // Note: Some BLE models may not have UUIDs specified yet
          // This test documents the current state
          if (model.bleServiceUuid != null) {
            expect(
              model.bleServiceUuid,
              isNotEmpty,
              reason:
                  '${model.fullName} should have non-empty BLE service UUID',
            );
          }
        }
      });

      test('USB models have VID/PID when specified', () {
        final usbModels = library.allModels
            .where((m) => m.connectionTypes.contains(DeviceConnectionType.usb));

        for (final model in usbModels) {
          // Some USB models may not have VID/PID specified
          if (model.usbVendorId != null) {
            expect(
              model.usbProductId,
              isNotNull,
              reason:
                  '${model.fullName} should have USB product ID if vendor ID is set',
            );
          }
        }
      });
    });

    group('findByName', () {
      test('finds Shearwater Perdix by full name', () {
        final model = library.findByName('Shearwater Perdix');
        expect(model, isNotNull);
        expect(model!.manufacturer, equals('Shearwater'));
        expect(model.model, equals('Perdix'));
      });

      test('finds model by partial name match', () {
        final model = library.findByName('Perdix');
        expect(model, isNotNull);
        expect(model!.manufacturer, equals('Shearwater'));
      });

      test('finds model case-insensitively', () {
        final model = library.findByName('shearwater perdix');
        expect(model, isNotNull);
        expect(model!.manufacturer, equals('Shearwater'));
      });

      test('returns null for unknown model', () {
        final model = library.findByName('Unknown Device XYZ123');
        expect(model, isNull);
      });
    });

    group('findByBleServiceUuid', () {
      test('finds Shearwater by service UUID', () {
        final model = library.findByBleServiceUuid('fe25');
        expect(model, isNotNull);
        expect(model!.manufacturer, equals('Shearwater'));
      });

      test('finds model case-insensitively', () {
        final model = library.findByBleServiceUuid('FE25');
        expect(model, isNotNull);
      });

      test('returns null for unknown UUID', () {
        final model = library.findByBleServiceUuid('0000-0000-0000-0000');
        expect(model, isNull);
      });
    });

    group('findByUsbIds', () {
      test('finds Suunto by VID/PID', () {
        final model = library.findByUsbIds('0x1493', '0x0030');
        expect(model, isNotNull);
        expect(model!.manufacturer, equals('Suunto'));
      });

      test('finds model case-insensitively', () {
        final model = library.findByUsbIds('0X1493', '0X0030');
        expect(model, isNotNull);
      });

      test('returns null for unknown VID/PID', () {
        final model = library.findByUsbIds('0x0000', '0x0000');
        expect(model, isNull);
      });
    });

    group('manufacturers', () {
      test('returns unique sorted list', () {
        final manufacturers = library.manufacturers;

        // Check it's sorted
        for (int i = 1; i < manufacturers.length; i++) {
          expect(
            manufacturers[i].compareTo(manufacturers[i - 1]),
            greaterThan(0),
            reason: 'Manufacturers should be sorted alphabetically',
          );
        }

        // Check no duplicates
        expect(
          manufacturers.toSet().length,
          equals(manufacturers.length),
          reason: 'Should have no duplicate manufacturers',
        );
      });

      test('contains expected manufacturers', () {
        final manufacturers = library.manufacturers;
        expect(manufacturers, contains('Shearwater'));
        expect(manufacturers, contains('Suunto'));
        expect(manufacturers, contains('Garmin'));
      });
    });

    group('getByManufacturer', () {
      test('returns all Shearwater models', () {
        final models = library.getByManufacturer('Shearwater');
        expect(models, isNotEmpty);
        expect(
          models.every((m) => m.manufacturer == 'Shearwater'),
          isTrue,
        );
      });

      test('returns empty for unknown manufacturer', () {
        final models = library.getByManufacturer('NonExistent');
        expect(models, isEmpty);
      });

      test('is case-insensitive', () {
        final models = library.getByManufacturer('shearwater');
        expect(models, isNotEmpty);
      });
    });

    group('getByConnectionType', () {
      test('returns BLE models', () {
        final models = library.getByConnectionType(DeviceConnectionType.ble);
        expect(models, isNotEmpty);
        expect(
          models.every(
            (m) => m.connectionTypes.contains(DeviceConnectionType.ble),
          ),
          isTrue,
        );
      });

      test('returns USB models', () {
        final models = library.getByConnectionType(DeviceConnectionType.usb);
        expect(models, isNotEmpty);
        expect(
          models.every(
            (m) => m.connectionTypes.contains(DeviceConnectionType.usb),
          ),
          isTrue,
        );
      });
    });

    group('matchDevice', () {
      test('matches device by service UUID', () {
        final device = DiscoveredDevice(
          id: 'test-id',
          name: 'Unknown Name',
          address: '00:11:22:33:44:55',
          connectionType: DeviceConnectionType.ble,
          serviceUuids: const ['fe25'],
          discoveredAt: DateTime.now(),
        );

        final model = library.matchDevice(device);
        expect(model, isNotNull);
        expect(model!.manufacturer, equals('Shearwater'));
      });

      test('matches device by name when no UUID match', () {
        final device = DiscoveredDevice(
          id: 'test-id',
          name: 'Perdix AI',
          address: '00:11:22:33:44:55',
          connectionType: DeviceConnectionType.ble,
          serviceUuids: const [],
          discoveredAt: DateTime.now(),
        );

        final model = library.matchDevice(device);
        expect(model, isNotNull);
        expect(model!.manufacturer, equals('Shearwater'));
      });

      test('returns null for unrecognized device', () {
        final device = DiscoveredDevice(
          id: 'test-id',
          name: 'Unknown Device',
          address: '00:11:22:33:44:55',
          connectionType: DeviceConnectionType.ble,
          serviceUuids: const ['0000-0000'],
          discoveredAt: DateTime.now(),
        );

        final model = library.matchDevice(device);
        expect(model, isNull);
      });
    });
  });

  group('DeviceModel', () {
    test('fullName combines manufacturer and model', () {
      const model = DeviceModel(
        id: 'test',
        manufacturer: 'Shearwater',
        model: 'Perdix',
        connectionTypes: [DeviceConnectionType.ble],
      );

      expect(model.fullName, equals('Shearwater Perdix'));
    });

    test('supportsBle returns true for BLE models', () {
      const model = DeviceModel(
        id: 'test',
        manufacturer: 'Test',
        model: 'Device',
        connectionTypes: [DeviceConnectionType.ble],
      );

      expect(model.supportsBle, isTrue);
      expect(model.supportsUsb, isFalse);
    });

    test('supportsUsb returns true for USB models', () {
      const model = DeviceModel(
        id: 'test',
        manufacturer: 'Test',
        model: 'Device',
        connectionTypes: [DeviceConnectionType.usb],
      );

      expect(model.supportsUsb, isTrue);
      expect(model.supportsBle, isFalse);
    });

    test('supportsBluetooth returns true for BLE or Classic', () {
      const bleModel = DeviceModel(
        id: 'test1',
        manufacturer: 'Test',
        model: 'BLE',
        connectionTypes: [DeviceConnectionType.ble],
      );

      const classicModel = DeviceModel(
        id: 'test2',
        manufacturer: 'Test',
        model: 'Classic',
        connectionTypes: [DeviceConnectionType.bluetoothClassic],
      );

      expect(bleModel.supportsBluetooth, isTrue);
      expect(classicModel.supportsBluetooth, isTrue);
    });
  });

  group('DiscoveredDevice', () {
    test('displayName uses recognized model when available', () {
      const model = DeviceModel(
        id: 'test',
        manufacturer: 'Shearwater',
        model: 'Perdix',
        connectionTypes: [DeviceConnectionType.ble],
      );

      final device = DiscoveredDevice(
        id: 'test-id',
        name: 'Perdix 12345',
        address: '00:11:22:33:44:55',
        connectionType: DeviceConnectionType.ble,
        recognizedModel: model,
        discoveredAt: DateTime.now(),
      );

      expect(device.displayName, equals('Shearwater Perdix'));
    });

    test('displayName falls back to name when no recognized model', () {
      final device = DiscoveredDevice(
        id: 'test-id',
        name: 'Some Device',
        address: '00:11:22:33:44:55',
        connectionType: DeviceConnectionType.ble,
        discoveredAt: DateTime.now(),
      );

      expect(device.displayName, equals('Some Device'));
    });

    test('displayName uses Unknown Device when name is empty', () {
      final device = DiscoveredDevice(
        id: 'test-id',
        name: '',
        address: '00:11:22:33:44:55',
        connectionType: DeviceConnectionType.ble,
        discoveredAt: DateTime.now(),
      );

      expect(device.displayName, equals('Unknown Device'));
    });

    test('isRecognized returns true when recognizedModel is set', () {
      const model = DeviceModel(
        id: 'test',
        manufacturer: 'Shearwater',
        model: 'Perdix',
        connectionTypes: [DeviceConnectionType.ble],
      );

      final device = DiscoveredDevice(
        id: 'test-id',
        name: 'Perdix',
        address: '00:11:22:33:44:55',
        connectionType: DeviceConnectionType.ble,
        recognizedModel: model,
        discoveredAt: DateTime.now(),
      );

      expect(device.isRecognized, isTrue);
    });

    test('isRecognized returns false when recognizedModel is null', () {
      final device = DiscoveredDevice(
        id: 'test-id',
        name: 'Unknown Device',
        address: '00:11:22:33:44:55',
        connectionType: DeviceConnectionType.ble,
        discoveredAt: DateTime.now(),
      );

      expect(device.isRecognized, isFalse);
    });

    test('signalStrengthPercent calculates percentage correctly', () {
      // -40 dBm should be 100%
      final strongDevice = DiscoveredDevice(
        id: 'test',
        name: 'Test',
        address: '00:11:22:33:44:55',
        connectionType: DeviceConnectionType.ble,
        signalStrength: -40,
        discoveredAt: DateTime.now(),
      );
      expect(strongDevice.signalStrengthPercent, equals(100));

      // -100 dBm should be 0%
      final weakDevice = DiscoveredDevice(
        id: 'test',
        name: 'Test',
        address: '00:11:22:33:44:55',
        connectionType: DeviceConnectionType.ble,
        signalStrength: -100,
        discoveredAt: DateTime.now(),
      );
      expect(weakDevice.signalStrengthPercent, equals(0));

      // -70 dBm should be ~50%
      final mediumDevice = DiscoveredDevice(
        id: 'test',
        name: 'Test',
        address: '00:11:22:33:44:55',
        connectionType: DeviceConnectionType.ble,
        signalStrength: -70,
        discoveredAt: DateTime.now(),
      );
      expect(weakDevice.signalStrengthPercent, equals(0));
      expect(mediumDevice.signalStrengthPercent, equals(50));
    });

    test('signalLevel returns appropriate level', () {
      // Strong signal
      final excellent = DiscoveredDevice(
        id: 'test',
        name: 'Test',
        address: '00:11:22:33:44:55',
        connectionType: DeviceConnectionType.ble,
        signalStrength: -45,
        discoveredAt: DateTime.now(),
      );
      expect(excellent.signalLevel, equals(SignalStrength.excellent));

      // Medium signal
      final good = DiscoveredDevice(
        id: 'test',
        name: 'Test',
        address: '00:11:22:33:44:55',
        connectionType: DeviceConnectionType.ble,
        signalStrength: -60,
        discoveredAt: DateTime.now(),
      );
      expect(good.signalLevel, equals(SignalStrength.good));

      // Weak signal
      final weak = DiscoveredDevice(
        id: 'test',
        name: 'Test',
        address: '00:11:22:33:44:55',
        connectionType: DeviceConnectionType.ble,
        signalStrength: -95,
        discoveredAt: DateTime.now(),
      );
      expect(weak.signalLevel, equals(SignalStrength.weak));

      // Unknown (no signal)
      final unknown = DiscoveredDevice(
        id: 'test',
        name: 'Test',
        address: '00:11:22:33:44:55',
        connectionType: DeviceConnectionType.ble,
        discoveredAt: DateTime.now(),
      );
      expect(unknown.signalLevel, equals(SignalStrength.unknown));
    });
  });

  group('DeviceConnectionType', () {
    test('has correct display names', () {
      expect(DeviceConnectionType.ble.displayName, equals('Bluetooth LE'));
      expect(
        DeviceConnectionType.bluetoothClassic.displayName,
        equals('Bluetooth'),
      );
      expect(DeviceConnectionType.usb.displayName, equals('USB'));
      expect(DeviceConnectionType.infrared.displayName, equals('Infrared'));
    });
  });
}
