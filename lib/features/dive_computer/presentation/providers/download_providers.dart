import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import '../../../../features/dive_log/domain/entities/dive_computer.dart';
import '../../data/services/dive_import_service.dart';
import '../../data/services/libdc_download_manager.dart';
import '../../domain/entities/device_model.dart';
import '../../domain/services/download_manager.dart';
import '../widgets/pin_entry_dialog.dart';
import 'discovery_providers.dart';

/// Provider for the dive computer repository.
final diveComputerRepositoryProvider = Provider<DiveComputerRepository>((ref) {
  return DiveComputerRepository();
});

/// Whether to use the mock download manager for development/testing.
/// Set to true to use simulated downloads instead of real device communication.
final useMockDownloadManagerProvider = StateProvider<bool>((ref) => false);

/// Provider for the download manager.
///
/// Uses MockDownloadManager for development/testing.
/// Switch to LibdcDownloadManager for real device communication.
final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final connectionManager = ref.watch(bluetoothConnectionManagerProvider);
  final useMock = ref.watch(useMockDownloadManagerProvider);

  if (useMock) {
    return MockDownloadManager(
      mockDiveCount: 5,
      downloadDelay: const Duration(milliseconds: 800),
    );
  }

  return LibdcDownloadManager(connectionManager: connectionManager);
});

/// Provider for the dive import service.
final diveImportServiceProvider = Provider<DiveImportService>((ref) {
  final repository = ref.watch(diveComputerRepositoryProvider);
  return DiveImportService(repository: repository);
});

/// Stream provider for download progress.
final downloadProgressProvider = StreamProvider<DownloadProgress>((ref) {
  final manager = ref.watch(downloadManagerProvider);
  return manager.progress;
});

/// Stream provider for individual downloaded dives.
final downloadedDivesStreamProvider = StreamProvider<DownloadedDive>((ref) {
  final manager = ref.watch(downloadManagerProvider);
  return manager.dives;
});

/// State for the download process.
class DownloadState {
  final DownloadPhase phase;
  final DownloadProgress? progress;
  final List<DownloadedDive> downloadedDives;
  final ImportResult? importResult;
  final String? errorMessage;
  final bool newDivesOnly;

  const DownloadState({
    this.phase = DownloadPhase.initializing,
    this.progress,
    this.downloadedDives = const [],
    this.importResult,
    this.errorMessage,
    this.newDivesOnly = true,
  });

  DownloadState copyWith({
    DownloadPhase? phase,
    DownloadProgress? progress,
    List<DownloadedDive>? downloadedDives,
    ImportResult? importResult,
    String? errorMessage,
    bool? newDivesOnly,
    bool clearError = false,
    bool clearImportResult = false,
  }) {
    return DownloadState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      downloadedDives: downloadedDives ?? this.downloadedDives,
      importResult: clearImportResult ? null : (importResult ?? this.importResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      newDivesOnly: newDivesOnly ?? this.newDivesOnly,
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
class DownloadNotifier extends StateNotifier<DownloadState> {
  final DownloadManager _downloadManager;
  final DiveImportService _importService;
  final DiveComputerRepository _repository;

  /// BuildContext for showing dialogs (e.g., PIN entry).
  /// Must be set before starting download for devices that require PIN.
  BuildContext? _dialogContext;

  DownloadNotifier({
    required DownloadManager downloadManager,
    required DiveImportService importService,
    required DiveComputerRepository repository,
  })  : _downloadManager = downloadManager,
        _importService = importService,
        _repository = repository,
        super(const DownloadState());

  /// Set the context to use for showing dialogs during download.
  ///
  /// Must be called before [startDownload] for devices that may
  /// require user interaction (e.g., Aqualung PIN entry).
  void setDialogContext(BuildContext context) {
    _dialogContext = context;
  }

  /// Set whether to download new dives only.
  void setNewDivesOnly(bool value) {
    state = state.copyWith(newDivesOnly: value);
  }

  /// Start downloading dives from the connected device.
  Future<DownloadResult> startDownload(DiscoveredDevice device) async {
    try {
      state = state.copyWith(
        phase: DownloadPhase.connecting,
        clearError: true,
        clearImportResult: true,
        downloadedDives: [],
      );

      // Set up PIN callback for devices that require it (e.g., Aqualung)
      if (_downloadManager is LibdcDownloadManager) {
        _downloadManager.onPinRequired = () async {
          if (_dialogContext == null || !_dialogContext!.mounted) {
            return null;
          }
          return PinEntryDialog.show(
            _dialogContext!,
            deviceName: device.recognizedModel?.fullName,
          );
        };
      }

      // Listen to progress updates
      _downloadManager.progress.listen((progress) {
        state = state.copyWith(
          phase: progress.phase,
          progress: progress,
        );
      });

      // Listen to individual dives
      _downloadManager.dives.listen((dive) {
        state = state.copyWith(
          downloadedDives: [...state.downloadedDives, dive],
        );
      });

      // Start download
      final result = await _downloadManager.downloadDives(
        device: device,
        newDivesOnly: state.newDivesOnly,
      );

      if (result.success) {
        state = state.copyWith(
          phase: DownloadPhase.complete,
          downloadedDives: result.dives,
        );
      } else {
        state = state.copyWith(
          phase: DownloadPhase.error,
          errorMessage: result.errorMessage,
        );
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        phase: DownloadPhase.error,
        errorMessage: 'Download failed: $e',
      );

      return DownloadResult.failure('$e', Duration.zero);
    }
  }

  /// Cancel the current download.
  Future<void> cancelDownload() async {
    await _downloadManager.cancel();
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
    state = const DownloadState();
  }
}

/// Provider for the download notifier.
final downloadNotifierProvider =
    StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  final downloadManager = ref.watch(downloadManagerProvider);
  final importService = ref.watch(diveImportServiceProvider);
  final repository = ref.watch(diveComputerRepositoryProvider);

  return DownloadNotifier(
    downloadManager: downloadManager,
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
