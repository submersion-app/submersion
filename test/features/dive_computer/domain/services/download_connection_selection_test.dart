import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_computer/domain/services/download_connection_selection.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

DiveComputer _computer() => DiveComputer(
  id: 'dc',
  name: 'Ratio iX3M 2',
  manufacturer: 'Ratio',
  model: 'iX3M 2',
  serialNumber: '74691',
  connectionType: 'bluetooth',
  bluetoothAddress: 'STALE',
  lastDiveFingerprint: 'fp',
  diveCount: 4,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

DiveComputerConnection _connection(
  String id,
  DiveComputerConnectionKind kind, {
  String? address,
  int? localAt,
  String? detail,
}) => DiveComputerConnection(
  id: id,
  computerId: 'dc',
  kind: kind,
  detail: detail,
  firstUsedAt: DateTime(2026),
  lastUsedAt: DateTime(2026, 2),
  address: address,
  localLastUsedAt: localAt == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(localAt),
);

void main() {
  final ble = _connection(
    'ble',
    DiveComputerConnectionKind.ble,
    address: 'AA',
    localAt: 100,
  );
  final usb = _connection(
    'usb',
    DiveComputerConnectionKind.usb,
    address: 'PORT',
    localAt: 200,
  );
  final fit = _connection(
    'fit',
    DiveComputerConnectionKind.file,
    detail: 'fit',
    address: 'X',
  );
  final elsewhere = _connection('far', DiveComputerConnectionKind.ble);

  group('connectionForDownload', () {
    test('the newest use on this device wins', () {
      expect(connectionForDownload([ble, usb, fit])?.id, 'usb');
    });

    test('an explicit reachable connection wins', () {
      expect(connectionForDownload([ble, usb], connectionId: 'ble')?.id, 'ble');
    });

    test('an explicit file connection, or one with no address here, falls '
        'back to the newest reachable', () {
      expect(connectionForDownload([ble, fit], connectionId: 'fit')?.id, 'ble');
      expect(
        connectionForDownload([ble, elsewhere], connectionId: 'far')?.id,
        'ble',
      );
    });

    test('null when nothing is reachable here', () {
      expect(connectionForDownload([fit, elsewhere]), isNull);
      expect(connectionForDownload(const []), isNull);
    });
  });

  group('computerForDownload', () {
    test('no connection rows: the computer is returned unchanged', () {
      final computer = _computer();
      expect(
        identical(computerForDownload(computer, const []), computer),
        isTrue,
      );
    });

    test('takes the transport and address of the chosen connection', () {
      final view = computerForDownload(_computer(), [ble, usb], selected: usb);
      expect(view.connectionType, 'usb');
      expect(view.bluetoothAddress, 'PORT');
      expect(view.lastDiveFingerprint, 'fp');
      expect(view.serialNumber, '74691');
      expect(view.diveCount, 4);
    });

    test('a Bluetooth Classic connection keeps its own transport name, so '
        'the wizard does not reopen it over BLE', () {
      final classic = _connection(
        'classic',
        DiveComputerConnectionKind.bluetoothClassic,
        address: 'CL',
        localAt: 300,
      );
      final view = computerForDownload(_computer(), [ble, classic]);
      expect(view.connectionType, 'bluetoothClassic');
      expect(view.bluetoothAddress, 'CL');
    });

    test('only file rows clears both, so the wizard does not dial a stale '
        'address', () {
      final view = computerForDownload(_computer(), [fit]);
      expect(view.connectionType, isNull);
      expect(view.bluetoothAddress, isNull);
      expect(view.id, 'dc');
    });

    // Issue #3710: a Bluetooth computer saved on a Mac synced to a phone
    // with its connection but no address, because the address is per
    // device. Clearing the transport too told the phone there was no
    // connection at all, so it never looked for the computer.
    test('a direct connection with no address here keeps its transport and '
        'drops the stale address, so the step can look for the computer', () {
      final view = computerForDownload(_computer(), [fit, elsewhere]);
      expect(view.connectionType, 'bluetooth');
      expect(view.bluetoothAddress, isNull);
      expect(view.lastDiveFingerprint, 'fp');
    });

    test('a USB connection with no port here keeps its transport, so iOS '
        'can explain that USB needs a desktop (issue #2837)', () {
      final usbFar = _connection('usb-far', DiveComputerConnectionKind.usb);
      final view = computerForDownload(_computer(), [usbFar]);
      expect(view.connectionType, 'usb');
      expect(view.bluetoothAddress, isNull);
    });

    test('with no address here, BLE wins over a newer connection of '
        'another transport, since only BLE can be found by a scan', () {
      DiveComputerConnection far(String id, DiveComputerConnectionKind kind) =>
          DiveComputerConnection(
            id: id,
            computerId: 'dc',
            kind: kind,
            firstUsedAt: DateTime(2026),
            lastUsedAt: DateTime(2026, 3),
          );
      final usbFar = far('usb-far', DiveComputerConnectionKind.usb);
      final classicFar = far(
        'classic-far',
        DiveComputerConnectionKind.bluetoothClassic,
      );
      for (final rows in [
        [elsewhere, usbFar],
        [usbFar, elsewhere],
        [classicFar, elsewhere],
      ]) {
        expect(
          computerForDownload(_computer(), rows).connectionType,
          'bluetooth',
        );
      }
    });

    test('without BLE, the connection another device used last names the '
        'transport', () {
      final usbOld = _connection('usb-old', DiveComputerConnectionKind.usb);
      final classicNew = DiveComputerConnection(
        id: 'classic-new',
        computerId: 'dc',
        kind: DiveComputerConnectionKind.bluetoothClassic,
        firstUsedAt: DateTime(2026),
        lastUsedAt: DateTime(2026, 3),
      );
      expect(
        computerForDownload(_computer(), [usbOld, classicNew]).connectionType,
        'bluetoothClassic',
      );
    });
  });
}
