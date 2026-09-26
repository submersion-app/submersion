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
import 'download_notifier_reported_model_test.mocks.dart';

const _address = 'D1:2C:3B:4A:59:68';

DiveComputer _savedComputer({
  String name = 'Cressi Cartesio',
  String? serialNumber = '74565',
}) {
  final now = DateTime(2026, 9, 26);
  return DiveComputer(
    id: 'dc-1',
    diverId: 'diver-1',
    name: name,
    manufacturer: 'Cressi',
    model: 'Cartesio',
    serialNumber: serialNumber,
    firmwareVersion: '300',
    connectionType: 'bluetooth',
    bluetoothAddress: _address,
    createdAt: now,
    updatedAt: now,
  );
}

DiscoveredDevice _device() => DiscoveredDevice(
  id: _address,
  name: '1_12345',
  connectionType: DeviceConnectionType.ble,
  address: _address,
  recognizedModel: const DeviceModel(
    id: 'cressi_cartesio',
    manufacturer: 'Cressi',
    model: 'Cartesio',
    connectionTypes: [DeviceConnectionType.ble],
    dcModel: 1,
  ),
  discoveredAt: DateTime(2026, 9, 26),
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

  Future<DiveComputer?> completeDownload({
    required DiveComputer computer,
    String? serialNumber = '74565',
    String? firmwareVersion = '300',
    String? reportedProduct,
    int? reportedModel,
  }) async {
    await notifier.startDownload(_device(), computer: computer);
    events.add(
      DownloadCompleteEvent(
        0,
        serialNumber: serialNumber,
        firmwareVersion: firmwareVersion,
        reportedProduct: reportedProduct,
        reportedModel: reportedModel,
      ),
    );
    await pumpEventQueue();
    return updates.lastOrNull;
  }

  // Issue #422: a Cressi Donatello behind Cressi's Bluetooth adapter scans
  // as a Cartesio, and names its real model during the download.
  group('DownloadNotifier reported model relabel', () {
    test('relabels the saved computer to the reported model', () async {
      final saved = await completeDownload(
        computer: _savedComputer(),
        reportedProduct: 'Donatello',
        reportedModel: 4,
      );
      expect(saved?.model, 'Donatello');
      expect(saved?.name, 'Cressi Donatello');
      expect(notifier.state.reportedProduct, 'Donatello');
      expect(notifier.state.reportedModel, 4);
    });

    test('keeps a custom name while relabeling', () async {
      final saved = await completeDownload(
        computer: _savedComputer(name: "Dad's computer"),
        reportedProduct: 'Donatello',
        reportedModel: 4,
      );
      expect(saved?.model, 'Donatello');
      expect(saved?.name, "Dad's computer");
    });

    test('persists a relabel even when nothing else changed', () async {
      final saved = await completeDownload(
        computer: _savedComputer(),
        serialNumber: null,
        firmwareVersion: null,
        reportedProduct: 'Donatello',
        reportedModel: 4,
      );
      expect(saved?.model, 'Donatello');
    });

    test('never relabels a record whose serial disagrees', () async {
      final saved = await completeDownload(
        computer: _savedComputer(serialNumber: '11111'),
        reportedProduct: 'Donatello',
        reportedModel: 4,
      );
      expect(saved, isNull);
    });

    test('leaves the model alone when the device reported nothing', () async {
      // The reported serial is persisted as before; the label is not touched.
      final saved = await completeDownload(computer: _savedComputer());
      expect(saved?.model, 'Cartesio');
      expect(saved?.name, 'Cressi Cartesio');
    });
  });
}
