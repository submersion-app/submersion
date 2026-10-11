import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart'
    hide DiscoveredDevice;
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

import 'download_notifier_address_rebind_test.mocks.dart';

const _address = 'C4E774E2-7D1F-DB41-EBD3-69D345D782F3';

DiveComputer _savedPerdix({String? serialNumber}) {
  final now = DateTime(2026, 10, 1);
  return DiveComputer(
    id: 'dc-1',
    diverId: 'diver-1',
    name: 'Shearwater Perdix 2',
    manufacturer: 'Shearwater',
    model: 'Perdix 2',
    serialNumber: serialNumber,
    connectionType: 'bluetooth',
    bluetoothAddress: _address,
    createdAt: now,
    updatedAt: now,
  );
}

DiscoveredDevice _perdix() => DiscoveredDevice(
  id: _address,
  name: 'Perdix 2',
  connectionType: DeviceConnectionType.ble,
  address: _address,
  recognizedModel: const DeviceModel(
    id: 'shearwater_perdix2',
    manufacturer: 'Shearwater',
    model: 'Perdix 2',
    connectionTypes: [DeviceConnectionType.ble],
    dcModel: 11,
  ),
  discoveredAt: DateTime(2026, 10, 1),
);

void main() {
  late MockDiveComputerRepository repository;
  late MockDiveComputerService service;
  late StreamController<DownloadEvent> events;
  late DownloadNotifier notifier;
  late List<DiveComputer> updates;

  setUp(() {
    repository = MockDiveComputerRepository();
    service = MockDiveComputerService();
    events = StreamController<DownloadEvent>.broadcast();
    updates = [];
    when(service.downloadEvents).thenAnswer((_) => events.stream);
    when(
      service.startDownload(any, fingerprint: anyNamed('fingerprint')),
    ).thenAnswer((_) async {});
    when(repository.updateComputer(any)).thenAnswer((invocation) async {
      updates.add(invocation.positionalArguments.first as DiveComputer);
    });
    notifier = DownloadNotifier(service: service, repository: repository);
  });

  tearDown(() async {
    notifier.dispose();
    await events.close();
  });

  Future<void> complete(DiveComputer computer, String serial) async {
    await notifier.startDownload(_perdix(), computer: computer);
    events.add(DownloadCompleteEvent(0, serialNumber: serial));
    await pumpEventQueue();
  }

  // Issue #3106: libdivecomputer reports a Shearwater serial in decimal while
  // the computer and Shearwater Cloud show it in hex.
  group('DownloadNotifier Shearwater serial', () {
    test('a decimal serial is stored and exposed as hex', () async {
      await complete(_savedPerdix(), '2712847316');
      expect(notifier.state.serialNumber, 'A1B2C3D4');
      expect(updates.last.serialNumber, 'A1B2C3D4');
    });

    test('a stored decimal serial is the same serial as the reported hex, '
        'so the record is still updated', () async {
      await complete(_savedPerdix(serialNumber: '2712847316'), '2712847316');
      expect(updates, isNotEmpty);
      expect(updates.last.serialNumber, 'A1B2C3D4');
    });

    test('a device with no recognized model still stores hex, and a stored '
        'hex serial is never overwritten by its decimal', () async {
      final bare = DiscoveredDevice(
        id: _address,
        name: 'Perdix 2',
        connectionType: DeviceConnectionType.ble,
        address: _address,
        discoveredAt: DateTime(2026, 10, 1),
      );
      await notifier.startDownload(
        bare,
        computer: _savedPerdix(serialNumber: 'A1B2C3D4'),
      );
      events.add(DownloadCompleteEvent(0, serialNumber: '2712847316'));
      await pumpEventQueue();

      expect(notifier.state.serialNumber, 'A1B2C3D4');
      for (final saved in updates) {
        expect(saved.serialNumber, 'A1B2C3D4');
      }
    });

    test(
      'a different Shearwater serial still leaves the record alone',
      () async {
        await complete(_savedPerdix(serialNumber: 'A1B2C3D4'), '2712847317');
        expect(updates, isEmpty);
      },
    );
  });
}
