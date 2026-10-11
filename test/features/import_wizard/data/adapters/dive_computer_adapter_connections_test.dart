import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/data/repositories/dive_computer_connection_repository.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';

import 'dive_computer_adapter_test.mocks.dart';

/// A recorded call to [DiveComputerConnectionRepository.recordConnection].
typedef _Recorded = ({
  String computerId,
  DiveComputerConnectionKind kind,
  String? address,
});

class _FakeConnections implements DiveComputerConnectionRepository {
  final recorded = <_Recorded>[];
  final computerIdByAddress = <String, String>{};

  @override
  Future<DiveComputerConnection> recordConnection({
    required String computerId,
    required DiveComputerConnectionKind kind,
    String? detail,
    String? address,
    DateTime? usedAt,
    bool notify = true,
  }) async {
    recorded.add((computerId: computerId, kind: kind, address: address));
    return DiveComputerConnection(
      id: 'c',
      computerId: computerId,
      kind: kind,
      firstUsedAt: DateTime(2026),
      lastUsedAt: DateTime(2026),
      address: address,
    );
  }

  @override
  Future<String?> computerIdForLocalAddress({
    required String address,
    String? diverId,
  }) async => computerIdByAddress[address];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DiveComputer _computer({
  String id = 'perdix',
  String? serialNumber = 'A1B2C3D4',
}) => DiveComputer(
  id: id,
  diverId: 'diver-1',
  name: 'Shearwater Perdix 2',
  manufacturer: 'Shearwater',
  model: 'Perdix 2',
  serialNumber: serialNumber,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

DiscoveredDevice _device({
  DeviceConnectionType type = DeviceConnectionType.ble,
  String address = 'AA:BB',
}) => DiscoveredDevice(
  id: address,
  name: 'Perdix 2',
  connectionType: type,
  address: address,
  recognizedModel: DeviceModel(
    id: 'shearwater_perdix2',
    manufacturer: 'Shearwater',
    model: 'Perdix 2',
    connectionTypes: [type],
  ),
  discoveredAt: DateTime(2026),
);

void main() {
  late MockDiveImportService importService;
  late MockDiveComputerRepository computers;
  late MockDiveRepository dives;
  late MockDiveConsolidationService consolidation;
  late _FakeConnections connections;

  setUp(() {
    importService = MockDiveImportService();
    computers = MockDiveComputerRepository();
    dives = MockDiveRepository();
    consolidation = MockDiveConsolidationService();
    connections = _FakeConnections();
  });

  DiveComputerAdapter adapter({DiveComputer? known}) => DiveComputerAdapter(
    importService: importService,
    computerRepository: computers,
    diveRepository: dives,
    consolidationService: consolidation,
    diverId: 'diver-1',
    knownComputer: known,
    connectionRepository: connections,
  );

  group('ensureComputer records the connection (#3106)', () {
    test('a first BLE download records ble with its address', () async {
      when(
        computers.createComputer(any),
      ).thenAnswer((_) async => _computer(id: 'new'));
      final a = adapter();
      await a.ensureComputer(device: _device(), serialNumber: 'A1B2C3D4');
      expect(connections.recorded, [
        (
          computerId: 'new',
          kind: DiveComputerConnectionKind.ble,
          address: 'AA:BB',
        ),
      ]);
    });

    test('a known computer downloaded over USB records usb with the '
        'port', () async {
      final a = adapter(known: _computer());
      await a.ensureComputer(
        device: _device(type: DeviceConnectionType.usb, address: 'PORT-1'),
        serialNumber: 'A1B2C3D4',
      );
      expect(connections.recorded, [
        (
          computerId: 'perdix',
          kind: DiveComputerConnectionKind.usb,
          address: 'PORT-1',
        ),
      ]);
    });

    test('a stored decimal serial and the reported hex are one computer, so '
        'the connection is recorded', () async {
      final a = adapter(known: _computer(serialNumber: '2712847316'));
      await a.ensureComputer(device: _device(), serialNumber: 'A1B2C3D4');
      expect(connections.recorded, hasLength(1));
    });

    test('another computer answering a saved download records '
        'nothing', () async {
      final a = adapter(known: _computer(serialNumber: 'A1B2C3D4'));
      await a.ensureComputer(device: _device(), serialNumber: '2712847317');
      expect(connections.recorded, isEmpty);
    });
  });

  group('resolveKnownComputer (#3106)', () {
    test('finds a computer by a USB port held in its connections', () async {
      connections.computerIdByAddress['PORT-1'] = 'perdix';
      when(
        computers.getComputerById('perdix'),
      ).thenAnswer((_) async => _computer());
      final a = adapter();
      await a.resolveKnownComputer(
        _device(type: DeviceConnectionType.usb, address: 'PORT-1'),
      );
      expect(a.computer?.id, 'perdix');
    });

    test('a second computer on the same USB port is not filed under the '
        'first', () async {
      // A port names the cable or the host, not the computer: two
      // computers sharing one interface cable resolve to the same record by
      // address, and only the serial the download reports tells them apart.
      connections.computerIdByAddress['PORT-1'] = 'perdix';
      when(
        computers.getComputerById('perdix'),
      ).thenAnswer((_) async => _computer());
      when(computers.createComputer(any)).thenAnswer(
        (_) async => _computer(id: 'second', serialNumber: 'B0B0B0B0'),
      );
      final a = adapter();
      final device = _device(type: DeviceConnectionType.usb, address: 'PORT-1');

      await a.resolveKnownComputer(device);
      expect(a.computer?.id, 'perdix');
      await a.ensureComputer(device: device, serialNumber: 'B0B0B0B0');

      expect(a.computer?.id, 'second');
      verify(computers.createComputer(any)).called(1);
      expect(connections.recorded.map((r) => r.computerId), ['second']);
    });

    test('falls back to the legacy Bluetooth address lookup', () async {
      when(
        computers.findByBluetoothAddress('AA:BB', diverId: 'diver-1'),
      ).thenAnswer((_) async => _computer(id: 'legacy'));
      final a = adapter();
      await a.resolveKnownComputer(_device());
      expect(a.computer?.id, 'legacy');
    });
  });
}
