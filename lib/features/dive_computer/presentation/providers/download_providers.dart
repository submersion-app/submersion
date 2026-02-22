import 'dart:async';

import 'package:flutter/material.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
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
  return DiveImportService(repository: repository);
});

/// Stream provider for download events from the service.
final downloadEventsProvider = StreamProvider<pigeon.DownloadEvent>((ref) {
  final service = ref.watch(diveComputerServiceProvider);
  return service.downloadEvents;
});

/// State for the download process.
class DownloadState {
  final DownloadPhase phase;
  final DownloadProgress? progress;
  final List<DownloadedDive> downloadedDives;
  final ImportResult? importResult;
  final String? errorMessage;
  final bool newDivesOnly;
  final String? serialNumber;
  final String? firmwareVersion;

  const DownloadState({
    this.phase = DownloadPhase.initializing,
    this.progress,
    this.downloadedDives = const [],
    this.importResult,
    this.errorMessage,
    this.newDivesOnly = true,
    this.serialNumber,
    this.firmwareVersion,
  });

  DownloadState copyWith({
    DownloadPhase? phase,
    DownloadProgress? progress,
    List<DownloadedDive>? downloadedDives,
    ImportResult? importResult,
    String? errorMessage,
    bool? newDivesOnly,
    String? serialNumber,
    String? firmwareVersion,
    bool clearError = false,
    bool clearImportResult = false,
  }) {
    return DownloadState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      downloadedDives: downloadedDives ?? this.downloadedDives,
      importResult: clearImportResult
          ? null
          : (importResult ?? this.importResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      newDivesOnly: newDivesOnly ?? this.newDivesOnly,
      serialNumber: serialNumber ?? this.serialNumber,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    );
  }

  /// Whether download is in progress.
  bool get isDownloading =>
      phase == DownloadPhase.connecting ||
      phase == DownloadPhase.downloading ||
      phase == DownloadPhase.enumerating;

  /// Whether download completed successfully.
  bool get isComplete => phase == DownloadPhase.complete;

  /// Whether there was an error.
  bool get hasError => phase == DownloadPhase.error || errorMessage != null;
}

/// Notifier for managing the download process.
///
/// Uses DiveComputerService to start downloads via libdivecomputer's
/// native platform backends. Listens to downloadEvents stream for
/// progress, dives, completion, and errors.
///
/// When [startDownload] is called with a [DiveComputer] and diverId,
/// the notifier automatically imports dives into the database when the
/// download completes. This eliminates widget lifecycle dependencies.
class DownloadNotifier extends StateNotifier<DownloadState> {
  final pigeon.DiveComputerService _service;
  final DiveImportService _importService;
  final DiveComputerRepository _repository;
  StreamSubscription<pigeon.DownloadEvent>? _downloadSubscription;

  // Stored for auto-import after download completes.
  DiveComputer? _autoImportComputer;
  String? _autoImportDiverId;

  DownloadNotifier({
    required pigeon.DiveComputerService service,
    required DiveImportService importService,
    required DiveComputerRepository repository,
  }) : _service = service,
       _importService = importService,
       _repository = repository,
       super(const DownloadState());

  /// Set the context to use for showing dialogs during download.
  ///
  /// Currently a no-op. PIN entry will be handled natively by
  /// libdivecomputer when needed.
  void setDialogContext(BuildContext context) {
    // PIN entry handled natively by libdivecomputer.
  }

  /// Set whether to download new dives only.
  void setNewDivesOnly(bool value) {
    state = state.copyWith(newDivesOnly: value);
  }

  /// Start downloading dives from the selected device.
  ///
  /// When [computer] and [diverId] are provided, the notifier will
  /// automatically import dives into the database when the download
  /// completes. This eliminates widget lifecycle dependencies.
  Future<void> startDownload(
    DiscoveredDevice device, {
    DiveComputer? computer,
    String? diverId,
  }) async {
    _autoImportComputer = computer;
    _autoImportDiverId = diverId;

    try {
      state = state.copyWith(
        phase: DownloadPhase.connecting,
        clearError: true,
        clearImportResult: true,
        downloadedDives: [],
        progress: DownloadProgress.connecting(),
      );

      _downloadSubscription?.cancel();
      _downloadSubscription = _service.downloadEvents.listen(_onDownloadEvent);

      await _service.startDownload(device.toPigeon());
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
        // Persist device info on computer, then auto-import.
        _persistDeviceInfoAndImport(serialNumber, firmwareVersion);
      case pigeon.DownloadErrorEvent(:final error):
        state = state.copyWith(
          phase: DownloadPhase.error,
          errorMessage: error.message,
        );
        _downloadSubscription?.cancel();
        _downloadSubscription = null;
    }
  }

  /// Persist device info on the computer record, then auto-import dives.
  ///
  /// The computer record must be updated BEFORE import so that
  /// `importProfile()` can read the serial/firmware and copy them
  /// onto each dive record for self-contained data.
  Future<void> _persistDeviceInfoAndImport(
    String? serialNumber,
    String? firmwareVersion,
  ) async {
    final computer = _autoImportComputer;
    if (computer == null) return;

    try {
      // Update computer with device info from DC_EVENT_DEVINFO.
      if (serialNumber != null || firmwareVersion != null) {
        final updated = computer.copyWith(
          serialNumber: serialNumber ?? computer.serialNumber,
          firmwareVersion: firmwareVersion ?? computer.firmwareVersion,
        );
        await _repository.updateComputer(updated);
        _autoImportComputer = updated;
      }

      // Auto-import dives if any were downloaded.
      if (state.downloadedDives.isNotEmpty) {
        await importDives(
          computer: _autoImportComputer!,
          mode: ImportMode.newOnly,
          defaultResolution: ConflictResolution.skip,
          diverId: _autoImportDiverId,
        );
      }
    } catch (e) {
      debugPrint('[DownloadNotifier] Device info persist/import failed: $e');
    }
  }

  /// Cancel the current download.
  Future<void> cancelDownload() async {
    _downloadSubscription?.cancel();
    _downloadSubscription = null;
    await _service.cancelDownload();
    state = state.copyWith(phase: DownloadPhase.cancelled);
  }

  /// Import downloaded dives into the app.
  Future<ImportResult> importDives({
    required DiveComputer computer,
    ImportMode mode = ImportMode.newOnly,
    ConflictResolution defaultResolution = ConflictResolution.skip,
    String? diverId,
  }) async {
    try {
      state = state.copyWith(phase: DownloadPhase.processing);

      final result = await _importService.importDives(
        dives: state.downloadedDives,
        computer: computer,
        mode: mode,
        defaultResolution: defaultResolution,
        diverId: diverId,
      );

      // Update the computer's dive count and last download
      await _repository.incrementDiveCount(computer.id, by: result.imported);
      await _repository.updateLastDownload(computer.id);

      state = state.copyWith(
        phase: DownloadPhase.complete,
        importResult: result,
      );

      return result;
    } catch (e) {
      state = state.copyWith(
        phase: DownloadPhase.error,
        errorMessage: 'Import failed: $e',
      );

      return ImportResult.failure('$e');
    }
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
      final importService = ref.watch(diveImportServiceProvider);
      final repository = ref.watch(diveComputerRepositoryProvider);

      return DownloadNotifier(
        service: service,
        importService: importService,
        repository: repository,
      );
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

/// Provider for dive computer statistics.
final computerStatsProvider = FutureProvider.family<DiveComputerStats, String>((
  ref,
  computerId,
) async {
  final repository = ref.watch(diveComputerRepositoryProvider);
  return repository.getComputerStats(computerId);
});

/// Provider for dive IDs imported from a specific computer.
final computerDiveIdsProvider = FutureProvider.family<List<String>, String>((
  ref,
  computerId,
) async {
  final repository = ref.watch(diveComputerRepositoryProvider);
  return repository.getDiveIdsForComputer(computerId);
});
