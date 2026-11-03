import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart'
    hide DiscoveredDevice;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

@GenerateMocks([DiveComputerRepository, DiveComputerService])
import 'download_notifier_address_rebind_test.mocks.dart';

const _staleAddress = 'CBB1EC06-5D7C-4F20-7A6C-98BBB2F8F631';
const _freshAddress = 'C4E774E2-7D1F-DB41-EBD3-69D345D782F3';

DiveComputer _savedComputer({
  String id = 'dc-1',
  String? serialNumber = '074691',
  String? bluetoothAddress = _staleAddress,
}) {
  final now = DateTime(2026, 8, 31);
  return DiveComputer(
    id: id,
    diverId: 'diver-1',
    name: 'Ratio iX3M 2021 GPS Fancy',
    manufacturer: 'Ratio',
    model: 'iX3M 2021 GPS Fancy',
    serialNumber: serialNumber,
    firmwareVersion: '5.0.0',
    connectionType: 'bluetooth',
    bluetoothAddress: bluetoothAddress,
    createdAt: now,
    updatedAt: now,
  );
}

DiscoveredDevice _device(
  String address, {
  DeviceConnectionType connectionType = DeviceConnectionType.ble,
}) => DiscoveredDevice(
  id: address,
  name: 'RATIO-074691',
  connectionType: connectionType,
  address: address,
  recognizedModel: const DeviceModel(
    id: 'ratio_ix3m',
    manufacturer: 'Ratio',
    model: 'iX3M 2021 GPS Fancy',
    connectionTypes: [DeviceConnectionType.ble],
    dcModel: 96,
  ),
  discoveredAt: DateTime(2026, 8, 31),
);

void main() {
  late MockDiveComputerRepository repository;
  late MockDiveComputerService service;
  late StreamController<DownloadEvent> events;
  late DownloadNotifier notifier;
  // Every computer record the notifier persisted, in order. Collected by the
  // stub rather than read back through verify(), which throws when nothing
  // was persisted; that lets the helper below return null honestly.
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

  Future<DiveComputer?> completeDownload({
    required DiveComputer computer,
    required DiscoveredDevice device,
    String? serialNumber = '074691',
    String? firmwareVersion = '5.0.0',
  }) async {
    await notifier.startDownload(device, computer: computer);
    events.add(
      DownloadCompleteEvent(
        0,
        serialNumber: serialNumber,
        firmwareVersion: firmwareVersion,
      ),
    );
    await pumpEventQueue();
    return updates.lastOrNull;
  }

  // Issue #1423: the address stored for a saved Bluetooth computer is a
  // host-local identifier that can change (iOS mints a new CoreBluetooth
  // identifier when the peripheral's address rotates). Once a download has
  // completed from a device under a different address, that address is the
  // one worth remembering.
  group('DownloadNotifier stored address rebind', () {
    test('persists the address the download actually used', () async {
      final saved = await completeDownload(
        computer: _savedComputer(),
        device: _device(_freshAddress),
      );
      expect(saved?.bluetoothAddress, _freshAddress);
      expect(saved?.serialNumber, '074691');
      expect(saved?.firmwareVersion, '5.0.0');
    });

    test('rebinds even when no serial or firmware was reported', () async {
      final saved = await completeDownload(
        computer: _savedComputer(),
        device: _device(_freshAddress),
        serialNumber: null,
        firmwareVersion: null,
      );
      expect(saved?.bluetoothAddress, _freshAddress);
      expect(saved?.serialNumber, '074691');
    });

    test(
      'blank serial and firmware strings do not erase stored values',
      () async {
        final saved = await completeDownload(
          computer: _savedComputer(),
          device: _device(_freshAddress),
          serialNumber: '',
          firmwareVersion: ' ',
        );
        expect(saved?.bluetoothAddress, _freshAddress);
        expect(saved?.serialNumber, '074691');
        expect(saved?.firmwareVersion, '5.0.0');
      },
    );

    test('fills in a missing stored address', () async {
      final saved = await completeDownload(
        computer: _savedComputer(bluetoothAddress: null),
        device: _device(_freshAddress),
      );
      expect(saved?.bluetoothAddress, _freshAddress);
    });

    test('leaves the address alone when it already matches', () async {
      final saved = await completeDownload(
        computer: _savedComputer(),
        device: _device(_staleAddress.toLowerCase()),
      );
      expect(saved?.bluetoothAddress, _staleAddress);
    });

    test('leaves the record untouched when the reported serial names another '
        'unit', () async {
      // The same-model fallback can only pick a device by model. A serial
      // that disagrees with the saved one means this download came from a
      // different physical computer: neither its address nor its serial or
      // firmware belong on the saved entry.
      final saved = await completeDownload(
        computer: _savedComputer(),
        device: _device(_freshAddress),
        serialNumber: '999999',
        firmwareVersion: '9.9.9',
      );
      expect(saved, isNull);
      expect(updates, isEmpty);
    });

    test('rebinds when the saved computer has no serial yet', () async {
      final saved = await completeDownload(
        computer: _savedComputer(serialNumber: null),
        device: _device(_freshAddress),
        serialNumber: '074691',
      );
      expect(saved?.bluetoothAddress, _freshAddress);
      expect(saved?.serialNumber, '074691');
    });

    test('never writes a USB port as a Bluetooth address', () async {
      final saved = await completeDownload(
        computer: _savedComputer(),
        device: _device(
          '/dev/ttyUSB0',
          connectionType: DeviceConnectionType.usb,
        ),
      );
      expect(saved?.bluetoothAddress, _staleAddress);
    });

    test('does nothing without a computer to update', () async {
      await notifier.startDownload(_device(_freshAddress));
      events.add(
        DownloadCompleteEvent(0, serialNumber: '074691', firmwareVersion: null),
      );
      await pumpEventQueue();
      expect(updates, isEmpty);
      verifyNever(repository.updateComputer(any));
    });

    // The completion handler fires the persist without awaiting it, so the
    // write can still be in flight when the next download starts. Refreshing
    // the tracked record after the write would point it back at the computer
    // that just finished, and the newer download would then persist its
    // serial and address onto that record instead of its own.
    test(
      'a persist finishing late does not capture the next download',
      () async {
        const secondStaleAddress = 'A1B2C3D4-0000-4000-8000-000000000001';
        const secondFreshAddress = 'A1B2C3D4-0000-4000-8000-000000000002';
        final firstWrite = Completer<void>();
        when(repository.updateComputer(any)).thenAnswer((invocation) async {
          updates.add(invocation.positionalArguments.first as DiveComputer);
          if (updates.length == 1) await firstWrite.future;
        });

        await notifier.startDownload(
          _device(_freshAddress),
          computer: _savedComputer(),
        );
        events.add(
          DownloadCompleteEvent(
            0,
            serialNumber: '074691',
            firmwareVersion: '5.0.0',
          ),
        );
        await pumpEventQueue();
        expect(updates.single.id, 'dc-1');

        // A second computer starts downloading while that write is parked.
        await notifier.startDownload(
          _device(secondFreshAddress),
          computer: _savedComputer(
            id: 'dc-2',
            serialNumber: '999999',
            bluetoothAddress: secondStaleAddress,
          ),
        );
        firstWrite.complete();
        await pumpEventQueue();

        events.add(
          DownloadCompleteEvent(
            0,
            serialNumber: '999999',
            firmwareVersion: '5.0.0',
          ),
        );
        await pumpEventQueue();

        // Its own record is rebound. Unguarded, the tracked record is the
        // first computer, whose stored serial 074691 contradicts the reported
        // 999999, so the second download persists nothing at all.
        expect(updates.last.id, 'dc-2');
        expect(updates.last.bluetoothAddress, secondFreshAddress);
      },
    );
  });
}
