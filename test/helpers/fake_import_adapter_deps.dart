import 'dart:async';

import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:libdivecomputer_plugin/src/dive_computer_service.dart'
    show DownloadEvent;
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

class _FakeDiveComputerService implements pigeon.DiveComputerService {
  @override
  Stream<pigeon.DiscoveredDevice> get discoveredDevices => const Stream.empty();
  @override
  Stream<void> get discoveryComplete => const Stream.empty();
  @override
  Stream<DownloadEvent> get downloadEvents => const Stream.empty();
  @override
  Future<List<pigeon.DeviceDescriptor>> getDeviceDescriptors() async => [];
  @override
  Future<String> getVersion() async => '0.0.0';
  @override
  Future<void> startDiscovery(pigeon.TransportType transport) async {}
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> startDownload(
    pigeon.DiscoveredDevice device, {
    String? fingerprint,
  }) async {}
  @override
  Future<void> cancelDownload() async {}
  @override
  Future<void> submitPinCode(String pinCode) async {}
  @override
  void onDeviceDiscovered(pigeon.DiscoveredDevice device) {}
  @override
  void onDiscoveryComplete() {}
  @override
  void onDownloadProgress(pigeon.DownloadProgress progress) {}
  @override
  void onDiveDownloaded(pigeon.ParsedDive dive) {}
  @override
  void onDownloadComplete(
    int totalDives,
    String? serialNumber,
    String? firmwareVersion,
  ) {}
  @override
  void onError(pigeon.DiveComputerError error) {}
  @override
  void onPinCodeRequired(String deviceAddress) {}
  @override
  void onLogEvent(String category, String level, String message) {}
  @override
  Stream<({String category, String level, String message})> get logEvents =>
      const Stream.empty();
  @override
  void dispose() {}
}

class _FakeDiveComputerRepository extends DiveComputerRepository {
  @override
  Future<void> updateComputer(dynamic computer) async {}
  @override
  Future<DiveComputer?> findByBluetoothAddress(
    String address, {
    String? diverId,
  }) async => null;
}

/// Bundle of fakes commonly needed when constructing a [DiveComputerAdapter]
/// for widget tests.
///
/// The [fakeService]'s [downloadEvents] returns an empty stream so the
/// [DownloadNotifier] doesn't hit platform channels during pump.
class FakeImportAdapterDeps {
  final pigeon.DiveComputerService fakeService = _FakeDiveComputerService();
  final DiveComputerRepository computerRepo = _FakeDiveComputerRepository();
  final DiveRepository diveRepo = DiveRepository();

  DiveImportService get importService =>
      DiveImportService(repository: computerRepo, diveRepository: diveRepo);
}
