import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_dive_mapper.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';

/// Provider for the dive computer repository.
final diveComputerRepositoryProvider = Provider<DiveComputerRepository>((ref) {
  return DiveComputerRepository();
});

/// Provider for the dive import service.
final diveImportServiceProvider = Provider<DiveImportService>((ref) {
  final repository = ref.watch(diveComputerRepositoryProvider);
  final diveRepository = ref.watch(diveRepositoryProvider);
  return DiveImportService(
    repository: repository,
    diveRepository: diveRepository,
  );
});

/// Stream provider for download events from the service.
final downloadEventsProvider = StreamProvider<pigeon.DownloadEvent>((ref) {
  final service = ref.watch(diveComputerServiceProvider);
  return service.downloadEvents;
});

/// State for the download process.
///
/// Tracks download phase, progress, downloaded dives, and device metadata.
/// Import/consolidation logic is handled by the unified import wizard via
/// [DiveComputerAdapter].
class DownloadState {
  final DownloadPhase phase;
  final DownloadProgress? progress;
  final List<DownloadedDive> downloadedDives;
  final String? errorMessage;
  final String? errorCode;
  final bool newDivesOnly;
  final String? serialNumber;
  final String? firmwareVersion;

  const DownloadState({
    this.phase = DownloadPhase.initializing,
    this.progress,
    this.downloadedDives = const [],
    this.errorMessage,
    this.errorCode,
    this.newDivesOnly = true,
    this.serialNumber,
    this.firmwareVersion,
  });

  DownloadState copyWith({
    DownloadPhase? phase,
    DownloadProgress? progress,
    List<DownloadedDive>? downloadedDives,
    String? errorMessage,
    String? errorCode,
    bool? newDivesOnly,
    String? serialNumber,
    String? firmwareVersion,
    bool clearError = false,
  }) {
    return DownloadState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      downloadedDives: downloadedDives ?? this.downloadedDives,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      newDivesOnly: newDivesOnly ?? this.newDivesOnly,
      serialNumber: serialNumber ?? this.serialNumber,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    );
  }

  /// Whether download is in progress.
  bool get isDownloading =>
      phase == DownloadPhase.connecting ||
      phase == DownloadPhase.downloading ||
      phase == DownloadPhase.enumerating ||
      phase == DownloadPhase.pinRequired;

  /// Whether download completed successfully.
  bool get isComplete => phase == DownloadPhase.complete;

  /// Whether download was cancelled.
  bool get isCancelled => phase == DownloadPhase.cancelled;

  /// Whether there was an error.
  bool get hasError => phase == DownloadPhase.error || errorMessage != null;
}

/// Notifier for managing the download process.
///
/// Uses DiveComputerService to start downloads via libdivecomputer's
/// native platform backends. Listens to downloadEvents stream for
/// progress, dives, completion, and errors.
///
/// When a [DiveComputer] is provided to [startDownload], the notifier
/// persists device info (serial number, firmware version) on the computer
/// record when the download completes. Import and consolidation are handled
/// by the unified import wizard via [DiveComputerAdapter].
class DownloadNotifier extends StateNotifier<DownloadState> {
  final pigeon.DiveComputerService _service;
  final DiveComputerRepository _repository;
  StreamSubscription<pigeon.DownloadEvent>? _downloadSubscription;

  // Stored for device info persistence after download completes.
  DiveComputer? _computer;

  DownloadNotifier({
    required pigeon.DiveComputerService service,
    required DiveComputerRepository repository,
  }) : _service = service,
       _repository = repository,
       super(const DownloadState());

  /// Set whether to download new dives only.
  void setNewDivesOnly(bool value) {
    state = state.copyWith(newDivesOnly: value);
  }

  /// Start downloading dives from the selected device.
  ///
  /// When [computer] is provided, the notifier persists device info
  /// (serial number, firmware version) on the computer record when the
  /// download completes.
  Future<void> startDownload(
    DiscoveredDevice device, {
    DiveComputer? computer,
  }) async {
    _computer = computer;

    try {
      state = state.copyWith(
        phase: DownloadPhase.connecting,
        clearError: true,
        downloadedDives: [],
        progress: DownloadProgress.connecting(),
      );

      _downloadSubscription?.cancel();
      _downloadSubscription = _service.downloadEvents.listen(_onDownloadEvent);

      // Determine fingerprint for incremental download.
      String? fingerprint;
      if (state.newDivesOnly && _computer?.lastDiveFingerprint != null) {
        fingerprint = _computer!.lastDiveFingerprint;
      }

      await _service.startDownload(device.toPigeon(), fingerprint: fingerprint);
    } catch (e) {
      state = state.copyWith(
        phase: DownloadPhase.error,
        errorMessage: 'Download failed: $e',
      );
    }
  }

  void _onDownloadEvent(pigeon.DownloadEvent event) {
    switch (event) {
      case pigeon.DownloadProgressEvent(:final progress):
        state = state.copyWith(
          phase: DownloadPhase.downloading,
          progress: DownloadProgress.downloading(
            progress.current,
            progress.total,
          ),
        );
      case pigeon.PinCodeRequestEvent():
        state = state.copyWith(phase: DownloadPhase.pinRequired);
      case pigeon.DiveDownloadedEvent(:final dive):
        final downloaded = parsedDiveToDownloaded(dive);
        state = state.copyWith(
          downloadedDives: [...state.downloadedDives, downloaded],
        );
      case pigeon.DownloadCompleteEvent(
        :final totalDives,
        :final serialNumber,
        :final firmwareVersion,
      ):
        state = state.copyWith(
          phase: DownloadPhase.complete,
          progress: DownloadProgress.complete(totalDives),
          serialNumber: serialNumber,
          firmwareVersion: firmwareVersion,
        );
        _downloadSubscription?.cancel();
        _downloadSubscription = null;
        // Persist device info on the computer record.
        _persistDeviceInfo(serialNumber, firmwareVersion);
      case pigeon.DownloadErrorEvent(:final error):
        state = state.copyWith(
          phase: DownloadPhase.error,
          errorMessage: error.message,
          errorCode: error.code,
        );
        _downloadSubscription?.cancel();
        _downloadSubscription = null;
    }
  }

  /// Persist device info (serial number, firmware version) on the computer
  /// record after a successful download.
  Future<void> _persistDeviceInfo(
    String? serialNumber,
    String? firmwareVersion,
  ) async {
    final computer = _computer;
    if (computer == null) return;

    try {
      if (serialNumber != null || firmwareVersion != null) {
        final updated = computer.copyWith(
          serialNumber: serialNumber ?? computer.serialNumber,
          firmwareVersion: firmwareVersion ?? computer.firmwareVersion,
        );
        await _repository.updateComputer(updated);
        _computer = updated;
      }
    } catch (e) {
      debugPrint('[DownloadNotifier] Device info persist failed: $e');
    }
  }

  /// Submit a PIN code for BLE authentication.
  ///
  /// Transitions back to connecting phase while the PIN is verified.
  Future<void> submitPinCode(String pin) async {
    state = state.copyWith(phase: DownloadPhase.connecting);
    await _service.submitPinCode(pin);
  }

  /// Cancel the current download.
  Future<void> cancelDownload() async {
    _downloadSubscription?.cancel();
    _downloadSubscription = null;
    await _service.cancelDownload();
    state = state.copyWith(phase: DownloadPhase.cancelled);
  }

  /// Reset the download state.
  void reset() {
    _downloadSubscription?.cancel();
    _downloadSubscription = null;
    state = const DownloadState();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for the download notifier.
final downloadNotifierProvider =
    StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
      final service = ref.watch(diveComputerServiceProvider);
      final repository = ref.watch(diveComputerRepositoryProvider);

      return DownloadNotifier(service: service, repository: repository);
    });

/// Provider for checking if a download is in progress.
final isDownloadingProvider = Provider<bool>((ref) {
  final state = ref.watch(downloadNotifierProvider);
  return state.isDownloading;
});

/// Provider for the current download progress percentage.
final downloadPercentageProvider = Provider<double>((ref) {
  final state = ref.watch(downloadNotifierProvider);
  return state.progress?.percentage ?? 0.0;
});

/// Provider for dive IDs imported from a specific computer.
final computerDiveIdsProvider = FutureProvider.family<List<String>, String>((
  ref,
  computerId,
) async {
  final repository = ref.watch(diveComputerRepositoryProvider);
  return repository.getDiveIdsForComputer(computerId);
});
