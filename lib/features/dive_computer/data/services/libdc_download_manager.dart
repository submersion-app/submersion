import 'dart:async';

import '../../domain/entities/device_model.dart';
import '../../domain/services/download_manager.dart';
import 'aqualung_ble_protocol.dart';
import 'bluetooth_connection_manager.dart';
import 'libdc_ffi_download_manager.dart';
import 'mares_ble_protocol.dart';
import 'shearwater_ble_protocol.dart';
import 'suunto_ble_protocol.dart';

/// Callback for requesting a PIN from the user.
///
/// Called when a device (like Aqualung) requires PIN authentication.
/// Should display a dialog to the user and return the entered PIN,
/// or null if the user cancelled.
typedef PinRequestCallback = Future<String?> Function();

/// Implementation of [DownloadManager] using libdivecomputer via the dive_computer package.
///
/// This manager handles the download of dives from connected dive computers.
/// It uses the dive_computer Flutter package for FFI communication with libdivecomputer.
///
/// Note: The dive_computer package is in early development. This implementation
/// provides a working interface that can be enhanced as the package matures.
class LibdcDownloadManager implements DownloadManager {
  final BluetoothConnectionManager _connectionManager;

  // Stream controllers
  final _progressController = StreamController<DownloadProgress>.broadcast();
  final _divesController = StreamController<DownloadedDive>.broadcast();

  // State
  DownloadProgress _currentProgress = DownloadProgress.initial();
  bool _isDownloading = false;
  bool _isCancelled = false;

  /// Callback for requesting a PIN from the user.
  ///
  /// Set this before calling [downloadDives] for Aqualung/Pelagic devices.
  /// If not set and a PIN is required, the download will fail.
  PinRequestCallback? onPinRequired;

  LibdcDownloadManager({
    required BluetoothConnectionManager connectionManager,
  }) : _connectionManager = connectionManager;

  @override
  Stream<DownloadProgress> get progress => _progressController.stream;

  @override
  Stream<DownloadedDive> get dives => _divesController.stream;

  @override
  DownloadProgress get currentProgress => _currentProgress;

  @override
  bool get isDownloading => _isDownloading;

  void _updateProgress(DownloadProgress progress) {
    _currentProgress = progress;
    _progressController.add(progress);
  }

  @override
  Future<DownloadResult> downloadDives({
    required DiscoveredDevice device,
    bool newDivesOnly = true,
    DateTime? sinceTimestamp,
  }) async {
    if (_isDownloading) {
      throw const DownloadException(
        'A download is already in progress',
        phase: DownloadPhase.error,
      );
    }

    _isDownloading = true;
    _isCancelled = false;
    final startTime = DateTime.now();
    final downloadedDives = <DownloadedDive>[];

    try {
      // Ensure we're connected
      if (!_connectionManager.isConnected) {
        _updateProgress(DownloadProgress.connecting());
        await _connectionManager.connect(device);
      }

      if (_isCancelled) {
        return DownloadResult.failure(
          'Download cancelled',
          DateTime.now().difference(startTime),
        );
      }

      _updateProgress(
        const DownloadProgress(
          currentDive: 0,
          totalDives: 0,
          percentage: 0.1,
          status: 'Reading device info...',
          phase: DownloadPhase.enumerating,
        ),
      );

      // Get the device model info for protocol selection
      final model = device.recognizedModel;
      if (model == null) {
        throw const DownloadException(
          'Unrecognized device model. Cannot determine download protocol.',
          phase: DownloadPhase.error,
        );
      }

      // Download dives using the appropriate protocol
      // Note: This is where we would integrate with the dive_computer package
      // For now, we'll use a simulated download for testing the UI
      final dives = await _downloadFromDevice(
        device: device,
        model: model,
        newDivesOnly: newDivesOnly,
        sinceTimestamp: sinceTimestamp,
      );

      for (final dive in dives) {
        if (_isCancelled) break;

        downloadedDives.add(dive);
        _divesController.add(dive);

        _updateProgress(
          DownloadProgress.downloading(
            downloadedDives.length,
            dives.length,
          ),
        );
      }

      if (_isCancelled) {
        return DownloadResult.failure(
          'Download cancelled',
          DateTime.now().difference(startTime),
        );
      }

      _updateProgress(DownloadProgress.complete(downloadedDives.length));

      return DownloadResult.success(
        downloadedDives,
        DateTime.now().difference(startTime),
      );
    } catch (e) {
      _updateProgress(
        DownloadProgress(
          currentDive: downloadedDives.length,
          totalDives: downloadedDives.length,
          percentage: 0.0,
          status: 'Error: $e',
          phase: DownloadPhase.error,
        ),
      );

      if (e is DownloadException) rethrow;

      throw DownloadException(
        'Download failed: $e',
        phase: DownloadPhase.error,
        originalError: e,
      );
    } finally {
      _isDownloading = false;
    }
  }

  /// Download dives from the device using the appropriate protocol.
  ///
  /// This method handles the actual communication with the dive computer.
  /// Routes to the appropriate download method based on connection type:
  /// - USB: Uses libdivecomputer FFI via LibdcFfiDownloadManager
  /// - BLE Shearwater: Uses native Dart BLE protocol
  /// - BLE other: Not yet supported (requires manufacturer-specific protocols)
  Future<List<DownloadedDive>> _downloadFromDevice({
    required DiscoveredDevice device,
    required DeviceModel model,
    required bool newDivesOnly,
    DateTime? sinceTimestamp,
  }) async {
    // Route based on connection type
    switch (device.connectionType) {
      case DeviceConnectionType.usb:
        // Use libdivecomputer FFI for USB devices
        return _downloadViaUsb(
          device: device,
          model: model,
          newDivesOnly: newDivesOnly,
          sinceTimestamp: sinceTimestamp,
        );

      case DeviceConnectionType.ble:
        // Route to manufacturer-specific BLE protocol
        final manufacturer = model.manufacturer.toLowerCase();

        switch (manufacturer) {
          case 'shearwater':
            return _downloadFromShearwater(
              device: device,
              newDivesOnly: newDivesOnly,
              sinceTimestamp: sinceTimestamp,
            );

          case 'suunto':
            return _downloadFromSuunto(
              device: device,
              newDivesOnly: newDivesOnly,
              sinceTimestamp: sinceTimestamp,
            );

          case 'mares':
            return _downloadFromMares(
              device: device,
              newDivesOnly: newDivesOnly,
              sinceTimestamp: sinceTimestamp,
            );

          case 'aqualung':
          case 'apeks':
            return _downloadFromAqualung(
              device: device,
              newDivesOnly: newDivesOnly,
              sinceTimestamp: sinceTimestamp,
            );

          default:
            // Other BLE manufacturers not yet supported
            throw DownloadException(
              'BLE communication not yet implemented for ${model.manufacturer}. '
              'Supported manufacturers: Shearwater, Suunto, Mares, Aqualung. '
              'Device: ${model.fullName}',
              phase: DownloadPhase.downloading,
            );
        }

      case DeviceConnectionType.bluetoothClassic:
        throw DownloadException(
          'Bluetooth Classic is not yet supported. '
          'Device: ${model.fullName}',
          phase: DownloadPhase.downloading,
        );

      case DeviceConnectionType.infrared:
        throw DownloadException(
          'Infrared connections are not supported. '
          'Device: ${model.fullName}',
          phase: DownloadPhase.downloading,
        );
    }
  }

  /// Download dives from a USB-connected device using libdivecomputer FFI.
  Future<List<DownloadedDive>> _downloadViaUsb({
    required DiscoveredDevice device,
    required DeviceModel model,
    required bool newDivesOnly,
    DateTime? sinceTimestamp,
  }) async {
    // Create the FFI download manager for USB devices
    final ffiManager = LibdcFfiDownloadManager();

    try {
      // Forward progress updates
      ffiManager.progress.listen((progress) {
        _updateProgress(progress);
      });

      // Download dives
      final result = await ffiManager.downloadDives(
        device: device,
        newDivesOnly: newDivesOnly,
        sinceTimestamp: sinceTimestamp,
      );

      if (result.success) {
        return result.dives;
      } else {
        throw DownloadException(
          result.errorMessage ?? 'USB download failed',
          phase: DownloadPhase.error,
        );
      }
    } finally {
      ffiManager.dispose();
    }
  }

  /// Download dives from a Shearwater device using the native Dart BLE protocol.
  Future<List<DownloadedDive>> _downloadFromShearwater({
    required DiscoveredDevice device,
    required bool newDivesOnly,
    DateTime? sinceTimestamp,
  }) async {
    // Get the BluetoothDevice from the connection manager
    final bluetoothDevice = _connectionManager.bluetoothDevice;
    if (bluetoothDevice == null) {
      throw const DownloadException(
        'Bluetooth device not connected',
        phase: DownloadPhase.connecting,
      );
    }

    final protocol = ShearwaterBleProtocol(bluetoothDevice);

    try {
      // Connect and discover services
      _updateProgress(
        const DownloadProgress(
          currentDive: 0,
          totalDives: 0,
          percentage: 0.15,
          status: 'Discovering services...',
          phase: DownloadPhase.enumerating,
        ),
      );
      await protocol.connect();

      if (_isCancelled) return [];

      // Download manifest
      _updateProgress(
        const DownloadProgress(
          currentDive: 0,
          totalDives: 0,
          percentage: 0.2,
          status: 'Reading dive manifest...',
          phase: DownloadPhase.enumerating,
        ),
      );
      final manifest = await protocol.downloadManifest();

      if (_isCancelled) return [];

      // Filter dives if needed
      var divesToDownload = manifest;
      if (newDivesOnly && sinceTimestamp != null) {
        divesToDownload = manifest
            .where((entry) => entry.dateTime.isAfter(sinceTimestamp))
            .toList();
      }

      if (divesToDownload.isEmpty) {
        return [];
      }

      // Download each dive
      final downloadedDives = <DownloadedDive>[];

      for (int i = 0; i < divesToDownload.length; i++) {
        if (_isCancelled) break;

        final entry = divesToDownload[i];

        _updateProgress(
          DownloadProgress(
            currentDive: i + 1,
            totalDives: divesToDownload.length,
            percentage: 0.2 + (0.7 * (i / divesToDownload.length)),
            status: 'Downloading dive ${entry.diveNumber}...',
            phase: DownloadPhase.downloading,
          ),
        );

        final dive = await protocol.downloadDive(entry);
        downloadedDives.add(dive);
        _divesController.add(dive);
      }

      return downloadedDives;
    } finally {
      await protocol.disconnect();
      protocol.dispose();
    }
  }

  /// Download dives from a Suunto device using the native Dart BLE protocol.
  Future<List<DownloadedDive>> _downloadFromSuunto({
    required DiscoveredDevice device,
    required bool newDivesOnly,
    DateTime? sinceTimestamp,
  }) async {
    final bluetoothDevice = _connectionManager.bluetoothDevice;
    if (bluetoothDevice == null) {
      throw const DownloadException(
        'Bluetooth device not connected',
        phase: DownloadPhase.connecting,
      );
    }

    final protocol = SuuntoBleProtocol(bluetoothDevice);

    try {
      _updateProgress(
        const DownloadProgress(
          currentDive: 0,
          totalDives: 0,
          percentage: 0.15,
          status: 'Discovering services...',
          phase: DownloadPhase.enumerating,
        ),
      );
      await protocol.connect();

      if (_isCancelled) return [];

      _updateProgress(
        const DownloadProgress(
          currentDive: 0,
          totalDives: 0,
          percentage: 0.2,
          status: 'Reading dive manifest...',
          phase: DownloadPhase.enumerating,
        ),
      );
      final manifest = await protocol.downloadManifest();

      if (_isCancelled) return [];

      // Filter dives if needed
      // Note: Suunto manifest doesn't have date info until we download
      // So we download all and filter after parsing
      final divesToDownload = manifest;

      if (divesToDownload.isEmpty) {
        return [];
      }

      final downloadedDives = <DownloadedDive>[];

      for (int i = 0; i < divesToDownload.length; i++) {
        if (_isCancelled) break;

        final entry = divesToDownload[i];

        _updateProgress(
          DownloadProgress(
            currentDive: i + 1,
            totalDives: divesToDownload.length,
            percentage: 0.2 + (0.7 * (i / divesToDownload.length)),
            status: 'Downloading dive ${entry.diveNumber}...',
            phase: DownloadPhase.downloading,
          ),
        );

        final dive = await protocol.downloadDive(entry);

        // Filter by timestamp if needed
        if (newDivesOnly && sinceTimestamp != null) {
          if (dive.startTime.isBefore(sinceTimestamp)) {
            continue;
          }
        }

        downloadedDives.add(dive);
        _divesController.add(dive);
      }

      return downloadedDives;
    } finally {
      await protocol.disconnect();
      protocol.dispose();
    }
  }

  /// Download dives from a Mares device using the native Dart BLE protocol.
  Future<List<DownloadedDive>> _downloadFromMares({
    required DiscoveredDevice device,
    required bool newDivesOnly,
    DateTime? sinceTimestamp,
  }) async {
    final bluetoothDevice = _connectionManager.bluetoothDevice;
    if (bluetoothDevice == null) {
      throw const DownloadException(
        'Bluetooth device not connected',
        phase: DownloadPhase.connecting,
      );
    }

    final protocol = MaresBleProtocol(bluetoothDevice);

    try {
      _updateProgress(
        const DownloadProgress(
          currentDive: 0,
          totalDives: 0,
          percentage: 0.15,
          status: 'Discovering services...',
          phase: DownloadPhase.enumerating,
        ),
      );
      await protocol.connect();

      if (_isCancelled) return [];

      _updateProgress(
        const DownloadProgress(
          currentDive: 0,
          totalDives: 0,
          percentage: 0.2,
          status: 'Downloading dive data...',
          phase: DownloadPhase.downloading,
        ),
      );

      // Mares downloads all dives at once from memory
      final dives = await protocol.downloadDives();

      if (_isCancelled) return [];

      // Filter by timestamp if needed
      var filteredDives = dives;
      if (newDivesOnly && sinceTimestamp != null) {
        filteredDives = dives
            .where((dive) => dive.startTime.isAfter(sinceTimestamp))
            .toList();
      }

      for (final dive in filteredDives) {
        _divesController.add(dive);
      }

      return filteredDives;
    } finally {
      await protocol.disconnect();
      protocol.dispose();
    }
  }

  /// Download dives from an Aqualung/Apeks device using the native Dart BLE protocol.
  Future<List<DownloadedDive>> _downloadFromAqualung({
    required DiscoveredDevice device,
    required bool newDivesOnly,
    DateTime? sinceTimestamp,
  }) async {
    final bluetoothDevice = _connectionManager.bluetoothDevice;
    if (bluetoothDevice == null) {
      throw const DownloadException(
        'Bluetooth device not connected',
        phase: DownloadPhase.connecting,
      );
    }

    final protocol = AqualungBleProtocol(bluetoothDevice);

    // Set up PIN callback using the external handler
    protocol.onPinRequired = () async {
      if (onPinRequired == null) {
        throw const DownloadException(
          'This device requires a PIN code but no PIN handler is configured. '
          'Check the dive computer display for the PIN code.',
          phase: DownloadPhase.connecting,
        );
      }

      // Update progress to show we're waiting for PIN
      _updateProgress(
        const DownloadProgress(
          currentDive: 0,
          totalDives: 0,
          percentage: 0.1,
          status: 'PIN required - check dive computer display',
          phase: DownloadPhase.connecting,
        ),
      );

      final pin = await onPinRequired!();

      if (pin == null || pin.isEmpty) {
        throw const DownloadException(
          'PIN entry was cancelled. '
          'A PIN code is required to connect to this device.',
          phase: DownloadPhase.connecting,
        );
      }

      return pin;
    };

    try {
      _updateProgress(
        const DownloadProgress(
          currentDive: 0,
          totalDives: 0,
          percentage: 0.15,
          status: 'Discovering services...',
          phase: DownloadPhase.enumerating,
        ),
      );
      await protocol.connect();

      if (_isCancelled) return [];

      _updateProgress(
        const DownloadProgress(
          currentDive: 0,
          totalDives: 0,
          percentage: 0.2,
          status: 'Downloading dive data...',
          phase: DownloadPhase.downloading,
        ),
      );

      // Aqualung downloads all dives at once from memory
      final dives = await protocol.downloadDives();

      if (_isCancelled) return [];

      // Filter by timestamp if needed
      var filteredDives = dives;
      if (newDivesOnly && sinceTimestamp != null) {
        filteredDives = dives
            .where((dive) => dive.startTime.isAfter(sinceTimestamp))
            .toList();
      }

      for (final dive in filteredDives) {
        _divesController.add(dive);
      }

      return filteredDives;
    } finally {
      await protocol.disconnect();
      protocol.dispose();
    }
  }

  @override
  Future<void> cancel() async {
    _isCancelled = true;

    if (_isDownloading) {
      _updateProgress(
        DownloadProgress(
          currentDive: _currentProgress.currentDive,
          totalDives: _currentProgress.totalDives,
          percentage: _currentProgress.percentage,
          status: 'Cancelling...',
          phase: DownloadPhase.cancelled,
        ),
      );
    }
  }

  @override
  void dispose() {
    _progressController.close();
    _divesController.close();
  }
}

/// A mock download manager for testing and development.
///
/// This simulates downloading dives without requiring actual device connection.
class MockDownloadManager implements DownloadManager {
  final _progressController = StreamController<DownloadProgress>.broadcast();
  final _divesController = StreamController<DownloadedDive>.broadcast();

  DownloadProgress _currentProgress = DownloadProgress.initial();
  bool _isDownloading = false;
  bool _isCancelled = false;

  /// Number of mock dives to generate
  final int mockDiveCount;

  /// Delay between simulated dive downloads
  final Duration downloadDelay;

  MockDownloadManager({
    this.mockDiveCount = 5,
    this.downloadDelay = const Duration(milliseconds: 500),
  });

  @override
  Stream<DownloadProgress> get progress => _progressController.stream;

  @override
  Stream<DownloadedDive> get dives => _divesController.stream;

  @override
  DownloadProgress get currentProgress => _currentProgress;

  @override
  bool get isDownloading => _isDownloading;

  void _updateProgress(DownloadProgress progress) {
    _currentProgress = progress;
    _progressController.add(progress);
  }

  @override
  Future<DownloadResult> downloadDives({
    required DiscoveredDevice device,
    bool newDivesOnly = true,
    DateTime? sinceTimestamp,
  }) async {
    if (_isDownloading) {
      throw const DownloadException('A download is already in progress');
    }

    _isDownloading = true;
    _isCancelled = false;
    final startTime = DateTime.now();
    final downloadedDives = <DownloadedDive>[];

    try {
      _updateProgress(DownloadProgress.connecting());
      await Future.delayed(const Duration(milliseconds: 500));

      if (_isCancelled) {
        return DownloadResult.failure(
          'Download cancelled',
          DateTime.now().difference(startTime),
        );
      }

      _updateProgress(
        const DownloadProgress(
          currentDive: 0,
          totalDives: 0,
          percentage: 0.1,
          status: 'Reading device info...',
          phase: DownloadPhase.enumerating,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 300));

      // Generate mock dives
      for (int i = 0; i < mockDiveCount; i++) {
        if (_isCancelled) break;

        await Future.delayed(downloadDelay);

        final dive = _generateMockDive(i + 1);
        downloadedDives.add(dive);
        _divesController.add(dive);

        _updateProgress(DownloadProgress.downloading(i + 1, mockDiveCount));
      }

      if (_isCancelled) {
        return DownloadResult.failure(
          'Download cancelled',
          DateTime.now().difference(startTime),
        );
      }

      _updateProgress(DownloadProgress.complete(downloadedDives.length));

      return DownloadResult.success(
        downloadedDives,
        DateTime.now().difference(startTime),
      );
    } finally {
      _isDownloading = false;
    }
  }

  DownloadedDive _generateMockDive(int number) {
    final now = DateTime.now();
    final diveStart = now.subtract(Duration(days: number * 7, hours: 10));
    final duration = 45 + (number * 5); // 45-70 minutes
    final maxDepth = 18.0 + (number * 2); // 18-28 meters

    // Generate profile
    final profile = <ProfileSample>[];
    const sampleInterval = 10; // seconds
    final totalSamples = (duration * 60) ~/ sampleInterval;

    for (int i = 0; i < totalSamples; i++) {
      final timeSeconds = i * sampleInterval;
      final progress = timeSeconds / (duration * 60);

      // Simple dive profile: descend, bottom, ascend
      double depth;
      if (progress < 0.1) {
        // Descent
        depth = maxDepth * (progress / 0.1);
      } else if (progress < 0.8) {
        // Bottom time with slight variation
        depth = maxDepth - (progress - 0.5).abs() * 2;
      } else {
        // Ascent
        depth = maxDepth * (1 - (progress - 0.8) / 0.2);
      }

      profile.add(
        ProfileSample(
          timeSeconds: timeSeconds,
          depth: depth.clamp(0.0, maxDepth),
          temperature: 22.0 - (depth * 0.2), // Cooler at depth
          pressure:
              200 - (timeSeconds / (duration * 60) * 150), // Tank pressure
          tankIndex: 0,
        ),
      );
    }

    return DownloadedDive(
      diveNumber: number,
      startTime: diveStart,
      durationSeconds: duration * 60,
      maxDepth: maxDepth,
      avgDepth: maxDepth * 0.7,
      minTemperature: 18.0,
      maxTemperature: 24.0,
      profile: profile,
      tanks: [
        const DownloadedTank(
          index: 0,
          o2Percent: 32.0,
          startPressure: 200.0,
          endPressure: 50.0,
          volumeLiters: 12.0,
        ),
      ],
      fingerprint: 'mock-dive-$number-${diveStart.millisecondsSinceEpoch}',
    );
  }

  @override
  Future<void> cancel() async {
    _isCancelled = true;

    if (_isDownloading) {
      _updateProgress(
        DownloadProgress(
          currentDive: _currentProgress.currentDive,
          totalDives: _currentProgress.totalDives,
          percentage: _currentProgress.percentage,
          status: 'Cancelling...',
          phase: DownloadPhase.cancelled,
        ),
      );
    }
  }

  @override
  void dispose() {
    _progressController.close();
    _divesController.close();
  }
}
