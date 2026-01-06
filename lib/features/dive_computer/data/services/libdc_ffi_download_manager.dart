import 'dart:async';

import 'package:dive_computer/dive_computer.dart' as dc;

import '../../../../core/services/logger_service.dart';
import '../../domain/entities/device_model.dart';
import '../../domain/services/download_manager.dart';

const _log = LoggerService('LibdcFfiDownloadManager');

/// Download manager that uses libdivecomputer FFI for USB/Serial devices.
///
/// This manager handles downloads from dive computers connected via USB cable
/// or serial port, using the dive_computer package's FFI bindings to
/// libdivecomputer.
class LibdcFfiDownloadManager implements DownloadManager {
  // Stream controllers
  final _progressController = StreamController<DownloadProgress>.broadcast();
  final _divesController = StreamController<DownloadedDive>.broadcast();

  // State
  DownloadProgress _currentProgress = DownloadProgress.initial();
  bool _isDownloading = false;
  bool _isCancelled = false;
  bool _isInitialized = false;

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

  /// Initialize the libdivecomputer context.
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    try {
      _log.info('Initializing libdivecomputer FFI...');
      dc.DiveComputer.instance.openConnection();
      _isInitialized = true;
      _log.info('libdivecomputer FFI initialized');
    } catch (e, stack) {
      _log.error('Failed to initialize libdivecomputer FFI', e, stack);
      rethrow;
    }
  }

  /// Get the list of computers supported by libdivecomputer.
  Future<List<dc.Computer>> getSupportedComputers() async {
    await _ensureInitialized();
    return dc.DiveComputer.instance.supportedComputers;
  }

  /// Find the libdivecomputer Computer matching our DeviceModel.
  Future<dc.Computer?> _findLibdcComputer(DeviceModel model) async {
    final computers = await getSupportedComputers();

    // Try to match by vendor/product name
    for (final computer in computers) {
      if (computer.vendor.toLowerCase() == model.manufacturer.toLowerCase() &&
          computer.product.toLowerCase() == model.model.toLowerCase()) {
        return computer;
      }
    }

    // Try partial match
    for (final computer in computers) {
      if (computer.vendor.toLowerCase() == model.manufacturer.toLowerCase() &&
          computer.product.toLowerCase().contains(model.model.toLowerCase())) {
        return computer;
      }
    }

    _log.warning(
      'No libdivecomputer match found for ${model.manufacturer} ${model.model}',
    );
    return null;
  }

  /// Determine the appropriate transport for the device connection type.
  dc.ComputerTransport? _getTransport(
    DeviceModel model,
    DeviceConnectionType connectionType,
  ) {
    switch (connectionType) {
      case DeviceConnectionType.usb:
        // Check what transports the device supports
        // Most USB dive computers use either USB HID or serial
        // This is a simplification - in practice we'd need to check the device
        return dc.ComputerTransport.serial;
      case DeviceConnectionType.ble:
      case DeviceConnectionType.bluetoothClassic:
      case DeviceConnectionType.infrared:
        // These are not supported by our FFI transport layer yet
        return null;
    }
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
      final model = device.recognizedModel;
      if (model == null) {
        throw const DownloadException(
          'Unrecognized device model. Cannot determine download protocol.',
          phase: DownloadPhase.error,
        );
      }

      // Check if this is a USB device
      if (device.connectionType != DeviceConnectionType.usb) {
        throw DownloadException(
          'LibdcFfiDownloadManager only supports USB devices. '
          'Got: ${device.connectionType.displayName}',
          phase: DownloadPhase.error,
        );
      }

      _updateProgress(
        const DownloadProgress(
          currentDive: 0,
          totalDives: 0,
          percentage: 0.05,
          status: 'Initializing libdivecomputer...',
          phase: DownloadPhase.initializing,
        ),
      );

      await _ensureInitialized();

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
          status: 'Finding device driver...',
          phase: DownloadPhase.connecting,
        ),
      );

      // Find the libdivecomputer computer descriptor
      final libdcComputer = await _findLibdcComputer(model);
      if (libdcComputer == null) {
        throw DownloadException(
          'Device not supported by libdivecomputer: ${model.fullName}',
          phase: DownloadPhase.error,
        );
      }

      _log.info('Found libdivecomputer driver: $libdcComputer');

      // Determine transport
      final transport = _getTransport(model, device.connectionType);
      if (transport == null) {
        throw DownloadException(
          'No suitable transport for ${device.connectionType.displayName}',
          phase: DownloadPhase.error,
        );
      }

      _log.info('Using transport: ${transport.name}');

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
          percentage: 0.15,
          status: 'Connecting to device...',
          phase: DownloadPhase.connecting,
        ),
      );

      // Perform the download
      // Note: This runs in an isolate and blocks until complete
      _updateProgress(
        const DownloadProgress(
          currentDive: 0,
          totalDives: 0,
          percentage: 0.2,
          status: 'Downloading dives...',
          phase: DownloadPhase.downloading,
        ),
      );

      // Get the last fingerprint for incremental downloads
      String? lastFingerprint;
      // TODO: Retrieve from database based on device

      final libdcDives = await dc.DiveComputer.instance.download(
        libdcComputer,
        transport,
        lastFingerprint,
      );

      _log.info('Downloaded ${libdcDives.length} dives from device');

      // Convert libdivecomputer dives to our format
      for (int i = 0; i < libdcDives.length; i++) {
        if (_isCancelled) break;

        final libdcDive = libdcDives[i];
        final convertedDive = _convertDive(libdcDive, i + 1);
        downloadedDives.add(convertedDive);
        _divesController.add(convertedDive);

        _updateProgress(DownloadProgress.downloading(i + 1, libdcDives.length));
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
        fingerprint: downloadedDives.isNotEmpty
            ? downloadedDives.first.fingerprint
            : null,
      );
    } catch (e, stack) {
      _log.error('Download failed', e, stack);

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

  /// Convert a libdivecomputer Dive to our DownloadedDive format.
  DownloadedDive _convertDive(dc.Dive dive, int diveNumber) {
    // Convert samples
    final profile = dive.samples.map((sample) {
      // Get first pressure reading if available
      double? pressure;
      int? tankIndex;
      if (sample.pressure != null && sample.pressure!.isNotEmpty) {
        final firstPressure = sample.pressure!.first;
        pressure = firstPressure.pressure;
        tankIndex = firstPressure.tank;
      }

      // Time from libdivecomputer - convert to seconds if in milliseconds
      // Some backends (e.g., Shearwater) return milliseconds, others return seconds
      // Detect by checking if value > 24 hours in seconds
      final timeSeconds = sample.time > 86400 ? sample.time ~/ 1000 : sample.time;

      return ProfileSample(
        timeSeconds: timeSeconds,
        depth: sample.depth ?? 0.0,
        temperature: sample.temperature,
        pressure: pressure,
        tankIndex: tankIndex,
        heartRate: sample.heartbeat,
        ppo2: sample.ppo2?.value,
        cns: sample.cns,
        ndl: sample.deco?.time,
        ceiling: sample.deco?.depth,
      );
    }).toList();

    // Convert tanks
    final tanks = <DownloadedTank>[];
    if (dive.tanks != null) {
      for (int i = 0; i < dive.tanks!.length; i++) {
        final tank = dive.tanks![i];

        // Get O2 percentage from gas mix
        double o2Percent = 21.0; // Default to air
        double hePercent = 0.0;
        if (dive.gasmixes != null && tank.gasmix < dive.gasmixes!.length) {
          final gasmix = dive.gasmixes![tank.gasmix];
          o2Percent = gasmix.oxygen * 100;
          hePercent = gasmix.helium * 100;
        }

        tanks.add(
          DownloadedTank(
            index: i,
            o2Percent: o2Percent,
            hePercent: hePercent,
            startPressure: tank.beginpressure,
            endPressure: tank.endpressure,
          ),
        );
      }
    }

    // Extract gas switches from samples
    final gasSwitches = <GasSwitchEvent>[];
    int? lastGasmix;
    for (final sample in dive.samples) {
      if (sample.gasmix != null && sample.gasmix != lastGasmix) {
        gasSwitches.add(
          GasSwitchEvent(
            timeSeconds: sample.time,
            depth: sample.depth ?? 0.0,
            toTankIndex: sample.gasmix!,
          ),
        );
        lastGasmix = sample.gasmix;
      }
    }

    return DownloadedDive(
      diveNumber: diveNumber,
      startTime: dive.dateTime ?? DateTime.now(),
      durationSeconds: dive.diveTime ?? 0,
      maxDepth: dive.maxDepth ?? 0.0,
      avgDepth: dive.avgDepth,
      minTemperature: dive.temperatureMinimum,
      maxTemperature: dive.temperatureMaximum,
      profile: profile,
      tanks: tanks,
      gasSwitches: gasSwitches,
      fingerprint: dive.hash,
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
    if (_isInitialized) {
      try {
        dc.DiveComputer.instance.closeConnection();
      } catch (e) {
        _log.warning('Error closing libdivecomputer connection', e);
      }
    }
    _progressController.close();
    _divesController.close();
  }
}
