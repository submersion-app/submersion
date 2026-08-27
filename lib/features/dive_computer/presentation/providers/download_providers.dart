import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_dive_mapper.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/domain/services/first_sync_cutoff.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/domain/services/default_tank_preset_resolver.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';

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
    gpsTrackMatchService: ref.watch(gpsTrackMatchServiceProvider),
    // Read at import time, not provider build time, so a toggle flipped in
    // Settings applies to the very next download (issue #386).
    defaultTankPresetForImports: () => loadDefaultTankPresetForDownloads(ref),
  );
});

/// The default tank preset to fill downloaded cylinders with, or null when
/// the diver has not opted in ("Also apply to imported dives" off) or the
/// configured preset no longer exists.
@visibleForTesting
Future<TankPresetEntity?> loadDefaultTankPresetForDownloads(Ref ref) async {
  final settings = ref.read(settingsProvider);
  if (!settings.applyDefaultTankToImports) return null;
  final resolver = DefaultTankPresetResolver(
    repository: ref.read(tankPresetRepositoryProvider),
  );
  return resolver.resolve(settings.defaultTankPreset);
}

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
  final DateTime? sinceCutoff;

  const DownloadState({
    this.phase = DownloadPhase.initializing,
    this.progress,
    this.downloadedDives = const [],
    this.errorMessage,
    this.errorCode,
    this.newDivesOnly = true,
    this.serialNumber,
    this.firmwareVersion,
    this.sinceCutoff,
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
    DateTime? sinceCutoff,
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
      sinceCutoff: sinceCutoff ?? this.sinceCutoff,
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
  static final LoggerService _log = LoggerService.forClass(DownloadNotifier);

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

  /// Set the first-sync cutoff. Dives at or before this time are excluded
  /// from the download for backends that support the timestamp floor.
  /// Cleared by [reset]; must be set after reset and before [startDownload],
  /// like the forceFullDownload flag.
  void setSinceCutoff(DateTime? value) {
    state = state.copyWith(sinceCutoff: value);
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

      // Determine fingerprint for incremental download. A stored fingerprint
      // (from a completed prior download) always wins. With none stored, a
      // first-sync cutoff is synthesized into a timestamp-floor fingerprint
      // for Shearwater petrel-family devices (the fork treats an unmatched
      // fingerprint as a timestamp floor; other backends never receive a
      // synthesized value).
      String? fingerprint;
      if (state.newDivesOnly) {
        fingerprint = _computer?.lastDiveFingerprint;
        final cutoff = state.sinceCutoff;
        final model = device.recognizedModel;
        if (fingerprint == null &&
            cutoff != null &&
            supportsTimestampFingerprintFloor(
              vendor: model?.manufacturer,
              product: model?.model,
            )) {
          fingerprint = synthesizeShearwaterFingerprint(cutoff);
        }
      }

      await _service.startDownload(device.toPigeon(), fingerprint: fingerprint);
    } catch (e, stackTrace) {
      _log.error(
        'Download failed',
        category: LogCategory.libdc,
        error: e,
        stackTrace: stackTrace,
      );
      // Cancel the event subscription so stray events from the native side
      // cannot mutate state after a synchronous start failure.
      _downloadSubscription?.cancel();
      _downloadSubscription = null;
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
        _log.error(
          'Download failed (${error.code}): ${error.message}',
          category: LogCategory.libdc,
        );
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
  // The dive DETAIL tick, not the computers tick: this query reads `dives` and
  // `dive_data_sources`, so the id list goes stale when a dive is deleted or a
  // download attributes a new source to one -- neither of which writes the
  // `dive_computers` registry the repository owns.
  ref.invalidateSelfWhen(
    ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
  );
  return repository.getDiveIdsForComputer(computerId);
});

/// Default first-sync cutoff: the newest dive in the active diver's log.
///
/// Null when there is no active diver or the log is empty (no cutoff
/// prompt is shown then).
///
/// `autoDispose`: this is only ever watched by `DcAdapterDownloadStep` while
/// the cutoff prompt could apply, and only for as long as that step widget
/// stays mounted. Without `autoDispose` a plain `FutureProvider` caches its
/// first resolved value (e.g. `null` from an empty log) for the app's
/// lifetime, so a later cutoff-eligible reconnect (after an intervening file
/// import populates the log) would never re-fetch and the prompt would stay
/// stuck showing stale data until app restart. `autoDispose` tears the
/// provider down once its last listener unmounts, so the next watch always
/// re-fetches. The download step watches it continuously while it's on
/// screen, so there's no risk of a mid-session refetch under an active
/// listener.
// no-tick: autoDispose, and it seeds a DEFAULT the user then edits. It is
// re-fetched every time the step mounts, so a stale value cannot render; a tick
// would instead move the default under the user mid-download, since the
// download itself writes the dives this reads.
final firstSyncCutoffDefaultProvider = FutureProvider.autoDispose<DateTime?>((
  ref,
) async {
  final diverId = ref.watch(currentDiverIdProvider);
  if (diverId == null || diverId.isEmpty) return null;
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getNewestDiveDateTime(diverId: diverId);
});
