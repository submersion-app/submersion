import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:libdivecomputer_plugin/src/dive_computer_service.dart'
    show DownloadEvent;
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/scan_step_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Fake DiveComputerService that avoids platform channels.
class FakeDiveComputerService implements pigeon.DiveComputerService {
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
    bool syncClock = false,
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
    String? clockSyncStatus,
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

/// DiscoveryNotifier subclass that never triggers platform channel calls.
///
/// Because [startScan] is a no-op, the notifier stays in its initial state:
/// not scanning, no devices, no error. The Bluetooth tab therefore renders
/// its empty state.
class TestDiscoveryNotifier extends DiscoveryNotifier {
  TestDiscoveryNotifier() : super(service: FakeDiveComputerService());

  @override
  Future<void> startScan() async {
    // no-op: avoid platform channel calls in tests
  }
}

/// Pumps [ScanStepWidget] inside a localized MaterialApp with the platform
/// dependent providers replaced by fakes.
Widget buildScanStepTestWidget({
  Map<String, List<DeviceModel>> usbDevices = const {},
}) {
  return ProviderScope(
    overrides: [
      usbDevicesByManufacturerProvider.overrideWith((ref) async => usbDevices),
      discoveryNotifierProvider.overrideWith((ref) => TestDiscoveryNotifier()),
    ],
    child: MaterialApp(
      // Pinned so finders on English literals do not depend on the host
      // locale of whoever runs the tests.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ScanStepWidget(onDeviceSelected: (_) {})),
    ),
  );
}
