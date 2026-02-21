import 'dart:async';

import 'package:libdivecomputer_plugin/src/generated/dive_computer_api.g.dart';

/// Events emitted during a download.
sealed class DownloadEvent {}

class DownloadProgressEvent extends DownloadEvent {
  final DownloadProgress progress;
  DownloadProgressEvent(this.progress);
}

class DiveDownloadedEvent extends DownloadEvent {
  final ParsedDive dive;
  DiveDownloadedEvent(this.dive);
}

class DownloadCompleteEvent extends DownloadEvent {
  final int totalDives;
  final String? serialNumber;
  final String? firmwareVersion;
  DownloadCompleteEvent(
    this.totalDives, {
    this.serialNumber,
    this.firmwareVersion,
  });
}

class DownloadErrorEvent extends DownloadEvent {
  final DiveComputerError error;
  DownloadErrorEvent(this.error);
}

/// High-level Dart service wrapping the Pigeon DiveComputerHostApi.
///
/// Provides a Stream-based interface over the callback-based Pigeon API.
/// Implements [DiveComputerFlutterApi] to receive native-initiated callbacks
/// for device discovery events, download progress, and dive data.
class DiveComputerService implements DiveComputerFlutterApi {
  final DiveComputerHostApi _hostApi;

  final _discoveredDevicesController =
      StreamController<DiscoveredDevice>.broadcast();
  final _discoveryCompleteController = StreamController<void>.broadcast();
  final _downloadEventsController = StreamController<DownloadEvent>.broadcast();

  DiveComputerService({DiveComputerHostApi? hostApi})
    : _hostApi = hostApi ?? DiveComputerHostApi();

  /// Stream of discovered devices during scanning.
  Stream<DiscoveredDevice> get discoveredDevices =>
      _discoveredDevicesController.stream;

  /// Stream that emits when discovery is complete.
  Stream<void> get discoveryComplete => _discoveryCompleteController.stream;

  /// Stream of download events (progress, dives, complete, error).
  Stream<DownloadEvent> get downloadEvents => _downloadEventsController.stream;

  /// Get all known device descriptors from libdivecomputer.
  Future<List<DeviceDescriptor>> getDeviceDescriptors() {
    return _hostApi.getDeviceDescriptors();
  }

  /// Get the libdivecomputer version string.
  Future<String> getVersion() {
    return _hostApi.getLibdivecomputerVersion();
  }

  /// Start scanning for dive computers.
  Future<void> startDiscovery(TransportType transport) {
    return _hostApi.startDiscovery(transport);
  }

  /// Stop scanning.
  Future<void> stopDiscovery() {
    return _hostApi.stopDiscovery();
  }

  /// Start downloading dives from a discovered device.
  Future<void> startDownload(DiscoveredDevice device) {
    return _hostApi.startDownload(device);
  }

  /// Cancel an ongoing download.
  Future<void> cancelDownload() {
    return _hostApi.cancelDownload();
  }

  // === DiveComputerFlutterApi callbacks (called from native) ===

  @override
  void onDeviceDiscovered(DiscoveredDevice device) {
    _discoveredDevicesController.add(device);
  }

  @override
  void onDiscoveryComplete() {
    _discoveryCompleteController.add(null);
  }

  @override
  void onDownloadProgress(DownloadProgress progress) {
    _downloadEventsController.add(DownloadProgressEvent(progress));
  }

  @override
  void onDiveDownloaded(ParsedDive dive) {
    _downloadEventsController.add(DiveDownloadedEvent(dive));
  }

  @override
  void onDownloadComplete(
    int totalDives,
    String? serialNumber,
    String? firmwareVersion,
  ) {
    _downloadEventsController.add(
      DownloadCompleteEvent(
        totalDives,
        serialNumber: serialNumber,
        firmwareVersion: firmwareVersion,
      ),
    );
  }

  @override
  void onError(DiveComputerError error) {
    _downloadEventsController.add(DownloadErrorEvent(error));
  }

  /// Dispose of all stream controllers.
  void dispose() {
    _discoveredDevicesController.close();
    _discoveryCompleteController.close();
    _downloadEventsController.close();
  }
}
