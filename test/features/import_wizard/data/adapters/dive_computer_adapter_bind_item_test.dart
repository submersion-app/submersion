import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';

import 'dive_computer_adapter_test.mocks.dart';

/// "Connect and download" on a hand-added Dive Computer item binds the
/// device it discovers to that item (issue #3676), and never silently
/// rebinds a device another item already stands for.
void main() {
  const diverId = 'diver-1';
  late MockDiveComputerRepository repo;

  final device = DiscoveredDevice(
    id: 'device-1',
    name: 'Teric',
    connectionType: DeviceConnectionType.ble,
    address: 'AA:BB',
    recognizedModel: const DeviceModel(
      id: 'shearwater_teric',
      manufacturer: 'Shearwater',
      model: 'Teric',
      connectionTypes: [DeviceConnectionType.ble],
    ),
    discoveredAt: DateTime(2026, 10, 1),
  );

  DiveComputer existing({String? equipmentId}) => DiveComputer(
    id: 'existing',
    name: 'Teric',
    diverId: diverId,
    manufacturer: 'Shearwater',
    model: 'Teric',
    serialNumber: 'S1',
    equipmentId: equipmentId,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  DiveComputerAdapter adapter() => DiveComputerAdapter(
    importService: MockDiveImportService(),
    computerRepository: repo,
    diveRepository: MockDiveRepository(),
    consolidationService: MockDiveConsolidationService(),
    diverId: diverId,
    bindEquipmentId: 'hand-1',
  );

  setUp(() => repo = MockDiveComputerRepository());

  test('a new device discovered from a hand-added item is created on that '
      'item', () async {
    when(
      repo.createComputer(any),
    ).thenAnswer((inv) async => inv.positionalArguments.first as DiveComputer);
    final a = adapter();

    await a.ensureComputer(device: device, serialNumber: 'S1');

    final created =
        verify(repo.createComputer(captureAny)).captured.single as DiveComputer;
    expect(created.equipmentId, 'hand-1');
    expect(a.boundToOtherItemId, isNull);
  });

  test('a device already registered to another item is not rebound and the '
      'adapter names that item', () async {
    when(
      repo.findByHardwareIdentity(
        manufacturer: anyNamed('manufacturer'),
        model: anyNamed('model'),
        serialNumber: anyNamed('serialNumber'),
        diverId: anyNamed('diverId'),
      ),
    ).thenAnswer((_) async => existing(equipmentId: 'other-item'));
    when(repo.updateComputer(any)).thenAnswer((_) async {});
    final a = adapter();

    await a.ensureComputer(device: device, serialNumber: 'S1');

    expect(a.computer?.equipmentId, 'other-item');
    expect(a.boundToOtherItemId, 'other-item');
    verifyNever(repo.createComputer(any));
  });

  test('a device already registered to this item binds quietly', () async {
    when(
      repo.findByHardwareIdentity(
        manufacturer: anyNamed('manufacturer'),
        model: anyNamed('model'),
        serialNumber: anyNamed('serialNumber'),
        diverId: anyNamed('diverId'),
      ),
    ).thenAnswer((_) async => existing(equipmentId: 'hand-1'));
    when(repo.updateComputer(any)).thenAnswer((_) async {});
    final a = adapter();

    await a.ensureComputer(device: device, serialNumber: 'S1');

    expect(a.boundToOtherItemId, isNull);
  });
}
