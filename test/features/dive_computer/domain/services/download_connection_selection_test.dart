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

    test('rows but none reachable here clears both, so the wizard does not '
        'dial a stale address', () {
      final view = computerForDownload(_computer(), [fit, elsewhere]);
      expect(view.connectionType, isNull);
      expect(view.bluetoothAddress, isNull);
      expect(view.id, 'dc');
    });
  });
}
