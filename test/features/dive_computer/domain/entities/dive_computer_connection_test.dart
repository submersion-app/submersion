import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';

void main() {
  group('diveComputerConnectionId', () {
    test('is stable for the same computer, kind and detail', () {
      final a = diveComputerConnectionId(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.file,
        detail: 'fit',
      );
      final b = diveComputerConnectionId(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.file,
        detail: 'fit',
      );
      expect(a, b);
    });

    test('differs by kind and by detail', () {
      final ble = diveComputerConnectionId(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.ble,
      );
      final usb = diveComputerConnectionId(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.usb,
      );
      final fit = diveComputerConnectionId(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.file,
        detail: 'fit',
      );
      final uddf = diveComputerConnectionId(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.file,
        detail: 'uddf',
      );
      expect({ble, usb, fit, uddf}, hasLength(4));
    });

    test('a null detail and an empty one are the same connection', () {
      expect(
        diveComputerConnectionId(
          computerId: 'dc',
          kind: DiveComputerConnectionKind.ble,
        ),
        diveComputerConnectionId(
          computerId: 'dc',
          kind: DiveComputerConnectionKind.ble,
          detail: '',
        ),
      );
    });
  });

  group('DiveComputerConnectionKind', () {
    test('round-trips through its wire name', () {
      for (final kind in DiveComputerConnectionKind.values) {
        expect(DiveComputerConnectionKind.fromWire(kind.name), kind);
      }
      expect(DiveComputerConnectionKind.fromWire('serial'), isNull);
      expect(DiveComputerConnectionKind.fromWire(null), isNull);
    });

    test('maps to and from the discovery transport', () {
      for (final type in DeviceConnectionType.values) {
        expect(
          DiveComputerConnectionKind.fromDevice(type).deviceConnectionType,
          type,
        );
      }
      expect(DiveComputerConnectionKind.file.deviceConnectionType, isNull);
      expect(DiveComputerConnectionKind.cloud.isDirect, isFalse);
      expect(DiveComputerConnectionKind.usb.isDirect, isTrue);
    });

    test('names the legacy connection_type it mirrors', () {
      expect(DiveComputerConnectionKind.ble.legacyConnectionType, 'bluetooth');
      expect(
        DiveComputerConnectionKind.bluetoothClassic.legacyConnectionType,
        'bluetooth',
      );
      expect(DiveComputerConnectionKind.usb.legacyConnectionType, 'usb');
      expect(
        DiveComputerConnectionKind.infrared.legacyConnectionType,
        'infrared',
      );
      expect(DiveComputerConnectionKind.cloud.legacyConnectionType, 'cloud');
      expect(DiveComputerConnectionKind.file.legacyConnectionType, isNull);
    });
  });

  group('DiveComputerConnection.reachableHere', () {
    DiveComputerConnection connection(
      DiveComputerConnectionKind kind, {
      String? address,
    }) => DiveComputerConnection(
      id: 'c',
      computerId: 'dc',
      kind: kind,
      firstUsedAt: DateTime(2026),
      lastUsedAt: DateTime(2026),
      address: address,
    );

    test('needs a direct kind and a non-blank address', () {
      expect(
        connection(DiveComputerConnectionKind.ble, address: 'AA').reachableHere,
        isTrue,
      );
      expect(
        connection(DiveComputerConnectionKind.ble, address: ' ').reachableHere,
        isFalse,
      );
      expect(connection(DiveComputerConnectionKind.usb).reachableHere, isFalse);
      expect(
        connection(DiveComputerConnectionKind.file, address: 'x').reachableHere,
        isFalse,
      );
    });
  });
}
