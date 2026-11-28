import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';

import 'dive_computer_adapter_test.mocks.dart';

/// A computer the wizard finds by its serial (a fresh discovery, another
/// host) has its firmware written here, not by the download notifier, so the
/// firmware history hears of it here too (issue #5104).
void main() {
  late MockDiveImportService importService;
  late MockDiveComputerRepository computers;
  late MockDiveRepository dives;
  late MockDiveConsolidationService consolidation;
  late List<(String?, String, String?)> reports;

  setUp(() {
    importService = MockDiveImportService();
    computers = MockDiveComputerRepository();
    dives = MockDiveRepository();
    consolidation = MockDiveConsolidationService();
    reports = [];
  });

  DiveComputer saved({String? firmware = '92'}) => DiveComputer(
    id: 'perdix',
    diverId: 'diver-1',
    name: 'Shearwater Perdix 2',
    manufacturer: 'Shearwater',
    model: 'Perdix 2',
    serialNumber: 'A1B2C3D4',
    firmwareVersion: firmware,
    equipmentId: 'eq1',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final device = DiscoveredDevice(
    id: 'AA:BB',
    name: 'Perdix 2',
    connectionType: DeviceConnectionType.ble,
    address: 'AA:BB',
    recognizedModel: const DeviceModel(
      id: 'shearwater_perdix2',
      manufacturer: 'Shearwater',
      model: 'Perdix 2',
      connectionTypes: [DeviceConnectionType.ble],
    ),
    discoveredAt: DateTime(2026),
  );

  DiveComputerAdapter adapter() => DiveComputerAdapter(
    importService: importService,
    computerRepository: computers,
    diveRepository: dives,
    consolidationService: consolidation,
    diverId: 'diver-1',
    reportFirmware: (computer, version, previous) async =>
        reports.add((computer.equipmentId, version, previous)),
  );

  test('a computer found by its serial reports its firmware with the '
      'version it held before', () async {
    when(
      computers.findByHardwareIdentity(
        manufacturer: anyNamed('manufacturer'),
        model: anyNamed('model'),
        serialNumber: anyNamed('serialNumber'),
        diverId: anyNamed('diverId'),
      ),
    ).thenAnswer((_) async => saved());
    when(computers.updateComputer(any)).thenAnswer((_) async {});

    await adapter().ensureComputer(
      device: device,
      serialNumber: 'A1B2C3D4',
      firmwareVersion: '95',
    );

    expect(reports, [('eq1', '95', '92')]);
  });

  test('no reported firmware reports nothing', () async {
    when(
      computers.findByHardwareIdentity(
        manufacturer: anyNamed('manufacturer'),
        model: anyNamed('model'),
        serialNumber: anyNamed('serialNumber'),
        diverId: anyNamed('diverId'),
      ),
    ).thenAnswer((_) async => saved());
    when(computers.updateComputer(any)).thenAnswer((_) async {});

    await adapter().ensureComputer(device: device, serialNumber: 'A1B2C3D4');

    expect(reports, isEmpty);
  });
}
