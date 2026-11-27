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
import 'download_notifier_firmware_test.mocks.dart';

const _address = 'C4E774E2-7D1F-DB41-EBD3-69D345D782F3';

DiveComputer _computer({
  String? equipmentId = 'eq1',
  String? serial = '074691',
}) {
  final now = DateTime(2026, 11, 1);
  return DiveComputer(
    id: 'dc-1',
    diverId: 'diver-1',
    name: 'Perdix 2',
    manufacturer: 'Shearwater',
    model: 'Perdix 2',
    serialNumber: serial,
    firmwareVersion: '92',
    connectionType: 'bluetooth',
    bluetoothAddress: _address,
    equipmentId: equipmentId,
    createdAt: now,
    updatedAt: now,
  );
}

final _device = DiscoveredDevice(
  id: _address,
  name: 'Perdix 2',
  connectionType: DeviceConnectionType.ble,
  address: _address,
  recognizedModel: const DeviceModel(
    id: 'shearwater_perdix2',
    manufacturer: 'Shearwater',
    model: 'Perdix 2',
    connectionTypes: [DeviceConnectionType.ble],
    dcModel: 1,
  ),
  discoveredAt: DateTime(2026, 11, 1),
);

/// A download that reports firmware hands it to the firmware recorder
/// (issue #5104), which decides whether it is an update to log.
void main() {
  late MockDiveComputerRepository repository;
  late MockDiveComputerService service;
  late StreamController<DownloadEvent> events;
  late List<(String, String)> reports;
  late List<DiveComputer> updates;
  late Future<void> Function(DiveComputer, String) reportFirmware;
  late DownloadNotifier notifier;

  setUp(() {
    repository = MockDiveComputerRepository();
    service = MockDiveComputerService();
    events = StreamController<DownloadEvent>.broadcast();
    reports = [];
    updates = [];
    reportFirmware = (computer, version) async =>
        reports.add((computer.equipmentId!, version));
    when(service.downloadEvents).thenAnswer((_) => events.stream);
    when(
      service.startDownload(any, fingerprint: anyNamed('fingerprint')),
    ).thenAnswer((_) async {});
    when(repository.updateComputer(any)).thenAnswer((invocation) async {
      updates.add(invocation.positionalArguments.first as DiveComputer);
    });
    notifier = DownloadNotifier(
      service: service,
      repository: repository,
      reportFirmware: (computer, version) => reportFirmware(computer, version),
    );
  });

  tearDown(() async {
    notifier.dispose();
    await events.close();
  });

  Future<void> complete(
    DiveComputer computer, {
    String? firmware,
    String? serial = '074691',
  }) async {
    await notifier.startDownload(_device, computer: computer);
    events.add(
      DownloadCompleteEvent(0, serialNumber: serial, firmwareVersion: firmware),
    );
    await pumpEventQueue();
  }

  test('a reported version goes to the recorder for the gear twin', () async {
    await complete(_computer(), firmware: ' 95 ');
    expect(reports, [('eq1', '95')]);
    expect(updates.single.firmwareVersion, '95');
  });

  test('no report, or a blank one, reaches nothing', () async {
    await complete(_computer(), firmware: null);
    await complete(_computer(), firmware: '  ');
    expect(reports, isEmpty);
  });

  test('a computer with no gear twin reaches nothing', () async {
    await complete(_computer(equipmentId: null), firmware: '95');
    expect(reports, isEmpty);
  });

  test('another unit (serial mismatch) reaches nothing', () async {
    await complete(_computer(), firmware: '95', serial: '999999');
    expect(reports, isEmpty);
    expect(updates, isEmpty);
  });

  test('a recorder that fails leaves the registration updated', () async {
    reportFirmware = (_, _) async => throw StateError('disk full');
    await complete(_computer(), firmware: '95');
    expect(updates.single.firmwareVersion, '95');
  });
}
