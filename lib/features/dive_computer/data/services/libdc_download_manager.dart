import 'dart:async';

import '../../domain/entities/device_model.dart';
import '../../domain/services/download_manager.dart';
import 'bluetooth_connection_manager.dart';

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
  /// Currently implements a placeholder that can be replaced with real
  /// dive_computer package integration.
  Future<List<DownloadedDive>> _downloadFromDevice({
    required DiscoveredDevice device,
    required DeviceModel model,
    required bool newDivesOnly,
    DateTime? sinceTimestamp,
  }) async {
    // TODO: Integrate with dive_computer package for real device communication
    //
    // The integration would look something like:
    //
    // 1. Initialize the dive_computer plugin:
    //    final dc = DiveComputer.instance;
    //    await dc.open(family: model.dcFamily, model: model.dcModel);
    //
    // 2. Set up the transport (Bluetooth):
    //    final transport = BluetoothTransport(_connectionManager.bluetoothDevice);
    //    await dc.setTransport(transport);
    //
    // 3. Download dives with progress callbacks:
    //    final dives = await dc.downloadDives(
    //      onProgress: (current, total) {
    //        _updateProgress(DownloadProgress.downloading(current, total));
    //      },
    //    );
    //
    // 4. Parse the dive data into our format
    //
    // For now, we throw an exception to indicate real implementation is needed
    throw DownloadException(
      'Device communication not yet implemented. '
      'The dive_computer package integration is required for actual downloads. '
      'Device: ${model.fullName} (${model.dcFamily})',
      phase: DownloadPhase.downloading,
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
