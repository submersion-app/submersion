import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/data/services/fingerprint_utils.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    hide DiveMatchResult;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_steps.dart';

// ---------------------------------------------------------------------------
// Bridge providers
// ---------------------------------------------------------------------------

/// Signals that the scan step can advance (a device has been selected).
final dcAdapterScanCanAdvanceProvider = StateProvider<bool>((ref) => false);

/// Signals that the confirm step can advance (user tapped Connect & Download).
final dcAdapterConfirmCanAdvanceProvider = StateProvider<bool>((ref) => false);

/// Signals that the download step can advance (download is complete).
final dcAdapterDownloadCanAdvanceProvider = StateProvider<bool>((ref) => false);

// ---------------------------------------------------------------------------
// DiveComputerAdapter
// ---------------------------------------------------------------------------

/// Outcome of a single `DiveComputerAdapter._consolidateDive` call.
///
/// Used by `DiveComputerAdapter.performImport` to keep the import summary
/// accurate when a consolidation cannot complete, instead of throwing and
/// aborting the rest of the import loop.
enum _ConsolidateOutcome {
  /// The download was imported and successfully folded into the target.
  consolidated,

  /// Skipped without importing: the target dive already has data from the
  /// same computer, which [DiveConsolidationService.apply] would always
  /// reject with `ArgumentError('sameComputer...')`.
  skippedSameComputer,

  /// The download was imported as a standalone dive, but folding it into
  /// the target failed unexpectedly. The orphaned standalone dive was
  /// deleted to avoid stranding it.
  failed,
}

/// Import source adapter for dive computer downloads.
///
/// Implements [ImportSourceAdapter] for the unified import wizard. Supports
/// dives only. This is the only adapter that supports the [consolidate]
/// duplicate action, allowing downloaded dives to be merged as a secondary
/// computer reading on an existing dive.
///
/// Two modes of operation:
///
/// **Discovery (new computer)** -- [knownComputer] is null.
/// Four acquisition steps: Scan, Pair, Confirm, Download.
///
/// **Quick download (known computer)** -- [knownComputer] is provided.
/// One acquisition step: Download (auto-scans for the known device).
class DiveComputerAdapter implements ImportSourceAdapter {
  static final _log = LoggerService.forClass(DiveComputerAdapter);

  DiveComputerAdapter({
    required DiveImportService importService,
    required DiveComputerRepository computerRepository,
    required DiveRepository diveRepository,
    required DiveConsolidationService consolidationService,
    required String diverId,
    DiveComputer? knownComputer,
    String? displayName,
    WidgetRef? ref,
    bool forceFullDownload = false,
  }) : _importService = importService,
       _computerRepository = computerRepository,
       _diveRepository = diveRepository,
       _consolidationService = consolidationService,
       _diverId = diverId,
       _knownComputer = knownComputer,
       _ref = ref,
       _forceFullDownload = forceFullDownload,
       _displayName =
           displayName ?? knownComputer?.displayName ?? 'Dive Computer';

  final DiveImportService _importService;
  final DiveComputerRepository _computerRepository;
  final DiveRepository _diveRepository;
  final DiveConsolidationService _consolidationService;
  final String _diverId;
  final DiveComputer? _knownComputer;
  final WidgetRef? _ref;
  final bool _forceFullDownload;
  final String _displayName;

  /// Whether this import session should bypass the fingerprint and download
  /// every dive on the device.
  ///
  /// Set by the route builder when the user triggers "Re-import all dives"
  /// from the DC detail page (via `?forceFull=true` query parameter).
  bool get forceFullDownload => _forceFullDownload;

  List<DownloadedDive> _downloadedDives = [];
  DiveComputer? _computer;
  String? _customDeviceName;

  // Session-level descriptor fields captured from the discovered device.
  String? _descriptorVendor;
  String? _descriptorProduct;
  int? _descriptorModel;
  String? _libdivecomputerVersion;

  /// Set by the wizard so the confirm step can navigate back to scan.
  VoidCallback? goBackFromConfirm;

  /// Whether this adapter was created for a known (previously paired) computer.
  bool get isKnownComputer => _knownComputer != null;

  /// Set a custom display name for the device (from the confirm step).
  void setCustomDeviceName(String? name) {
    _customDeviceName = name?.trim().isNotEmpty == true ? name!.trim() : null;
  }

  /// The computer used for import (set during discovery or provided at construction).
  DiveComputer? get computer => _computer ?? _knownComputer;

  /// Load the list of downloaded dives into this adapter.
  ///
  /// Called by the download step widget when the download completes.
  /// Must be called before [buildBundle].
  void setDownloadedDives(List<DownloadedDive> dives) {
    _downloadedDives = List.unmodifiable(dives);
  }

  /// Set the computer after discovery completes.
  void setComputer(DiveComputer computer) {
    _computer = computer;
  }

  /// Look up an existing computer by the discovered device's address.
  ///
  /// Called before the download starts in discovery mode. If a matching
  /// computer is found for the current diver, its [lastDiveFingerprint]
  /// enables incremental download (only new dives). Does NOT create a new
  /// computer record -- that happens in [ensureComputer] after the download
  /// completes.
  Future<void> resolveKnownComputer(DiscoveredDevice device) async {
    if (computer != null) return;
    if (device.connectionType == DeviceConnectionType.ble ||
        device.connectionType == DeviceConnectionType.bluetoothClassic) {
      if (_diverId.isEmpty) return;
      final existing = await _computerRepository.findByBluetoothAddress(
        device.address,
        diverId: _diverId,
      );
      if (existing != null) {
        _computer = existing;
      }
    }
  }

  /// Create or find the dive computer record from the discovered device info.
  ///
  /// Called by the download step after a successful download in discovery mode.
  /// In known-computer mode this is a no-op.
  ///
  /// Also captures the session-level descriptor fields (vendor, product, model,
  /// and libdivecomputer version) so they can be passed to the import service
  /// before dives are written to the database.
  Future<void> ensureComputer({
    required DiscoveredDevice device,
    String? serialNumber,
    String? firmwareVersion,
  }) async {
    // Capture descriptor fields regardless of whether a computer record already
    // exists — these are always needed for the import service.
    final model = device.recognizedModel;
    if (model != null) {
      _descriptorVendor = model.manufacturer;
      _descriptorProduct = model.model;
      _descriptorModel = model.dcModel;
    }

    // Fetch the libdivecomputer version string once per session.
    if (_libdivecomputerVersion == null) {
      final dcService = _ref?.read(diveComputerServiceProvider);
      if (dcService != null) {
        try {
          _libdivecomputerVersion = await dcService.getVersion();
        } catch (_) {
          // Non-fatal — version metadata is best-effort.
        }
      }
    }

    if (computer != null) return;

    // Create a new computer record from the discovered device.
    final connectionTypeStr = switch (device.connectionType) {
      DeviceConnectionType.ble => 'bluetooth',
      DeviceConnectionType.bluetoothClassic => 'bluetooth',
      DeviceConnectionType.usb => 'usb',
      DeviceConnectionType.infrared => 'infrared',
    };

    final newComputer =
        DiveComputer.create(
          id: const Uuid().v4(),
          name: _customDeviceName ?? device.displayName,
          diverId: _diverId,
          manufacturer: device.manufacturer,
          model: device.model,
        ).copyWith(
          serialNumber: serialNumber,
          firmwareVersion: firmwareVersion,
          connectionType: connectionTypeStr,
          bluetoothAddress: device.address,
        );

    _computer = await _computerRepository.createComputer(newComputer);
  }

  // ---------------------------------------------------------------------------
  // ImportSourceAdapter interface
  // ---------------------------------------------------------------------------

  @override
  void resetState() {
    final ref = _ref;
    if (ref == null) return;
    ref.invalidate(dcAdapterScanCanAdvanceProvider);
    ref.invalidate(dcAdapterConfirmCanAdvanceProvider);
    ref.invalidate(dcAdapterDownloadCanAdvanceProvider);
    ref.read(downloadNotifierProvider.notifier).reset();
    // Only reset discovery state in discovery mode. In known-computer mode,
    // the download step reads the device from discoveryNotifierProvider;
    // clearing it would leave device null and the download can't start.
    if (!isKnownComputer) {
      ref.read(discoveryNotifierProvider.notifier).reset();
    }
  }

  @override
  ImportSourceType get sourceType => ImportSourceType.diveComputer;

  @override
  String get displayName => _displayName;

  @override
  String get defaultTagName {
    final name = (_customDeviceName ?? _computer?.name ?? _displayName).trim();
    final now = DateTime.now();
    final date =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final base = name.toLowerCase().endsWith('import') ? name : '$name Import';
    return '$base $date';
  }

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
    DuplicateAction.consolidate,
    DuplicateAction.replaceSource,
  };

  @override
  List<WizardStepDef> get acquisitionSteps {
    if (isKnownComputer) {
      return [
        WizardStepDef(
          label: 'Download',
          icon: Icons.download,
          builder: (context) => DcAdapterDownloadStep(
            adapter: this,
            knownComputer: _knownComputer,
          ),
          canAdvance: dcAdapterDownloadCanAdvanceProvider,
          autoAdvance: true,
        ),
      ];
    }

    return [
      WizardStepDef(
        label: 'Scan',
        icon: Icons.bluetooth_searching,
        builder: (context) => DcAdapterScanStep(adapter: this),
        canAdvance: dcAdapterScanCanAdvanceProvider,
        autoAdvance: true,
      ),
      WizardStepDef(
        label: 'Confirm',
        icon: Icons.check_circle,
        builder: (context) =>
            DcConfirmDeviceStep(adapter: this, onGoBack: goBackFromConfirm),
        canAdvance: dcAdapterConfirmCanAdvanceProvider,
        autoAdvance: true,
        hideBottomBar: true,
      ),
      WizardStepDef(
        label: 'Download',
        icon: Icons.download,
        builder: (context) => DcAdapterDownloadStep(adapter: this),
        canAdvance: dcAdapterDownloadCanAdvanceProvider,
        autoAdvance: true,
      ),
    ];
  }

  @override
  Future<ImportBundle> buildBundle() async {
    final items = _downloadedDives.map(_diveToEntityItem).toList();

    return ImportBundle(
      source: ImportSourceInfo(
        type: ImportSourceType.diveComputer,
        displayName: _displayName,
        currentComputerId: computer?.id,
      ),
      groups: {ImportEntityType.dives: EntityGroup(items: items)},
    );
  }

  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) async {
    final diveGroup = bundle.groups[ImportEntityType.dives];
    if (diveGroup == null || diveGroup.items.isEmpty) return bundle;

    final duplicateIndices = <int>{};
    final matchResults = <int, DiveMatchResult>{};

    // Prefetch the source-key map once for the whole download; the
    // fingerprint pass in detectDuplicate scans it per dive.
    final sourceKeysCache = await _diveRepository.getSourceKeysByDiveId(
      diverId: _diverId,
    );

    for (var i = 0; i < _downloadedDives.length; i++) {
      final dive = _downloadedDives[i];
      final result = await _importService.detectDuplicate(
        dive,
        diverId: _diverId,
        sourceKeysCache: sourceKeysCache,
      );

      if (result.isDuplicate && result.score >= 0.5) {
        duplicateIndices.add(i);
        final matchedComputerId = await _diveRepository.getComputerIdForDive(
          result.matchingDiveId!,
        );
        matchResults[i] = DiveMatchResult(
          diveId: result.matchingDiveId!,
          score: result.score,
          timeDifferenceMs: (result.timeDifferenceSeconds ?? 0) * 1000,
          depthDifferenceMeters: result.depthDifferenceMeters,
          durationDifferenceSeconds: null,
          matchedComputerId: matchedComputerId,
          matchedExistingSource: result.matchedExistingSource,
        );
      }
    }

    return ImportBundle(
      source: bundle.source,
      groups: {
        ...bundle.groups,
        ImportEntityType.dives: EntityGroup(
          items: diveGroup.items,
          duplicateIndices: duplicateIndices,
          matchResults: matchResults,
        ),
      },
    );
  }

  @override
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    bool retainSourceDiveNumbers = false,
    ImportProgressCallback? onProgress,
    ImportCancellationToken? cancelToken,
  }) async {
    final comp = computer;
    if (comp == null) {
      return const UnifiedImportResult(
        importedCounts: {},
        consolidatedCount: 0,
        skippedCount: 0,
        errorMessage: 'No dive computer available for import',
      );
    }

    final baseSelections = Set<int>.from(
      selections[ImportEntityType.dives] ?? <int>{},
    );
    final diveActions = duplicateActions[ImportEntityType.dives] ?? {};

    // Build the final set of indices and track actions.
    final indicesToImport = <int>{};
    final indicesToConsolidate = <int>{};
    final indicesToReplaceSource = <int>{};
    var skipped = 0;

    for (final index in baseSelections) {
      final action = diveActions[index];
      if (action == DuplicateAction.skip) {
        skipped++;
      } else if (action == DuplicateAction.consolidate) {
        indicesToConsolidate.add(index);
      } else if (action == DuplicateAction.replaceSource) {
        indicesToReplaceSource.add(index);
      } else {
        indicesToImport.add(index);
      }
    }

    for (final entry in diveActions.entries) {
      if (entry.value == DuplicateAction.importAsNew) {
        indicesToImport.add(entry.key);
      } else if (entry.value == DuplicateAction.consolidate &&
          !baseSelections.contains(entry.key)) {
        indicesToConsolidate.add(entry.key);
      } else if (entry.value == DuplicateAction.replaceSource &&
          !baseSelections.contains(entry.key)) {
        indicesToReplaceSource.add(entry.key);
      } else if (entry.value == DuplicateAction.skip &&
          !baseSelections.contains(entry.key)) {
        skipped++;
      }
    }

    // Merge and sort indices by startTime (oldest first) so sequential
    // dive number assignment produces correct chronological numbering.
    final allIndices =
        {
          ...indicesToImport,
          ...indicesToConsolidate,
          ...indicesToReplaceSource,
        }.toList()..sort((a, b) {
          final aTime = _downloadedDives[a].startTime;
          final bTime = _downloadedDives[b].startTime;
          return aTime.compareTo(bTime);
        });
    final total = allIndices.length;
    var imported = 0;
    var consolidated = 0;
    var updated = 0;
    final processedDives = <DownloadedDive>[];
    final importedDiveIds = <String>[];

    for (var i = 0; i < allIndices.length; i++) {
      if (cancelToken?.isCancelled ?? false) break;

      final index = allIndices[i];
      if (index >= _downloadedDives.length) continue;

      final dive = _downloadedDives[index];

      if (indicesToConsolidate.contains(index)) {
        // Consolidate: add as secondary computer reading on matched dive.
        final diveGroup = bundle.groups[ImportEntityType.dives];
        final matchResult = diveGroup?.matchResults?[index];
        if (matchResult != null) {
          final outcome = await _consolidateDive(
            dive,
            matchResult.diveId,
            comp,
          );
          switch (outcome) {
            case _ConsolidateOutcome.consolidated:
              consolidated++;
            case _ConsolidateOutcome.skippedSameComputer:
            case _ConsolidateOutcome.failed:
              skipped++;
          }
        }
      } else if (indicesToReplaceSource.contains(index)) {
        // Replace source: update the matched dive's source data with the
        // freshly downloaded version.
        final diveGroup = bundle.groups[ImportEntityType.dives];
        final matchResult = diveGroup?.matchResults?[index];
        if (matchResult != null) {
          final conflict = ImportConflict(
            downloaded: dive,
            existingDiveId: matchResult.diveId,
            duplicateResult: DuplicateResult(
              matchingDiveId: matchResult.diveId,
              confidence: DuplicateConfidence.exact,
              score: matchResult.score,
            ),
          );
          await _importService.resolveConflict(
            conflict,
            ConflictResolution.replaceSource,
            comp.id,
            diverId: _diverId,
            descriptorVendor: _descriptorVendor,
            descriptorProduct: _descriptorProduct,
            descriptorModel: _descriptorModel,
            libdivecomputerVersion: _libdivecomputerVersion,
          );
          updated++;
        }
      } else {
        // Import as new dive. Use importSingleDiveAsNew to bypass the
        // service's internal duplicate detection — the wizard has already
        // resolved duplicates and the user's choice must be respected.
        final diveId = await _importService.importSingleDiveAsNew(
          dive,
          computerId: comp.id,
          diverId: _diverId,
          descriptorVendor: _descriptorVendor,
          descriptorProduct: _descriptorProduct,
          descriptorModel: _descriptorModel,
          libdivecomputerVersion: _libdivecomputerVersion,
        );
        imported++;
        importedDiveIds.add(diveId);
      }

      processedDives.add(dive);
      onProgress?.call(ImportPhase.dives, i + 1, total);
    }

    // Update computer metadata.
    //
    // Normal completion uses ALL downloaded dives so skipped/consolidated
    // dives aren't re-downloaded next session. On cancellation we only advance
    // the fingerprint for the dives we actually processed, so the user can
    // re-import the remainder next time.
    final wasCancelled = cancelToken?.isCancelled ?? false;
    await _updateComputerAfterImport(
      comp,
      imported,
      wasCancelled ? processedDives : _downloadedDives,
    );

    return UnifiedImportResult(
      importedCounts: {ImportEntityType.dives: imported},
      consolidatedCount: consolidated,
      updatedCount: updated,
      skippedCount: skipped,
      importedDiveIds: importedDiveIds,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static final _dateFormatter = DateFormat('MMM d, yyyy');
  static final _timeFormatter = DateFormat('h:mm a');

  EntityItem _diveToEntityItem(DownloadedDive dive) {
    final dateStr = _dateFormatter.format(dive.startTime);
    final timeStr = _timeFormatter.format(dive.startTime);
    final title = '$dateStr \u2014 $timeStr';

    final settings = _ref?.read(settingsProvider) ?? const AppSettings();
    final units = UnitFormatter(settings);
    final durationMin = dive.duration.inMinutes;
    final tempStr = dive.minTemperature != null
        ? ' \u00b7 ${units.formatTemperature(dive.minTemperature!, decimals: 1)}'
        : '';
    final subtitle =
        '${units.formatDepth(dive.maxDepth)} max \u00b7 $durationMin min$tempStr';

    final comp = computer;
    final diveData = IncomingDiveData.fromDownloadedDive(dive, computer: comp);

    return EntityItem(title: title, subtitle: subtitle, diveData: diveData);
  }

  /// Consolidate a downloaded dive as a secondary computer reading on an
  /// existing dive.
  ///
  /// Imports the download as a standalone new dive first -- persisting every
  /// sample column, tanks, pressures, events, and the raw-data
  /// `dive_data_sources` row via [DiveImportService.importSingleDiveAsNew] /
  /// `importProfile` -- then folds it into [targetDiveId] via
  /// [DiveConsolidationService.apply]. This gives full-fidelity
  /// consolidation instead of a hand-rolled copy that would drop heart
  /// rate, O2 sensors, CNS/TTS samples, tanks, and events.
  ///
  /// The import and the fold are NOT atomic (there is no cross-table
  /// transaction spanning both repository calls), so this method guards
  /// both failure modes rather than letting either strand a dangling dive:
  ///
  /// - **Predictable failure (pre-validated, nothing imported):**
  ///   [DiveConsolidationService.apply] always throws `ArgumentError`
  ///   ("sameComputer...") when the secondary shares [targetDiveId]'s
  ///   `computerId`. Checking that up front avoids importing a dive that is
  ///   guaranteed to fail the fold.
  /// - **Unexpected failure (compensated):** if the import succeeds but
  ///   `apply` throws for any other reason, the freshly-imported dive is
  ///   deleted via [DiveRepository.bulkDeleteDives] (tombstone-honoring)
  ///   instead of being left as a bare, unconsolidated duplicate.
  ///
  /// Returns a [_ConsolidateOutcome] describing what happened so the caller
  /// can adjust the import summary's counters instead of aborting the loop.
  Future<_ConsolidateOutcome> _consolidateDive(
    DownloadedDive dive,
    String targetDiveId,
    DiveComputer comp,
  ) async {
    final targetComputerId = await _diveRepository.getComputerIdForDive(
      targetDiveId,
    );
    if (targetComputerId != null && targetComputerId == comp.id) {
      return _ConsolidateOutcome.skippedSameComputer;
    }

    String? newDiveId;
    try {
      newDiveId = await _importService.importSingleDiveAsNew(
        dive,
        computerId: comp.id,
        diverId: _diverId,
        descriptorVendor: _descriptorVendor,
        descriptorProduct: _descriptorProduct,
        descriptorModel: _descriptorModel,
        libdivecomputerVersion: _libdivecomputerVersion,
      );
      await _consolidationService.apply(
        targetDiveId: targetDiveId,
        secondaryDiveIds: [newDiveId],
      );
      return _ConsolidateOutcome.consolidated;
    } catch (e, st) {
      _log.error(
        'Consolidation fold failed for dive into $targetDiveId',
        error: e,
        stackTrace: st,
      );
      if (newDiveId != null) {
        try {
          await _diveRepository.bulkDeleteDives([newDiveId]);
        } catch (deleteError, deleteStack) {
          // The compensating delete failed too -- log it and fall through
          // rather than rethrow, so the import loop still processes the
          // remaining dives instead of aborting on a stranded standalone
          // dive.
          _log.error(
            'Compensating delete failed for orphaned dive $newDiveId',
            error: deleteError,
            stackTrace: deleteStack,
          );
        }
      }
      return _ConsolidateOutcome.failed;
    }
  }

  /// Update computer dive count, last download, and fingerprint after import.
  Future<void> _updateComputerAfterImport(
    DiveComputer comp,
    int importedCount,
    List<DownloadedDive> importedDives,
  ) async {
    if (importedCount > 0) {
      await _computerRepository.incrementDiveCount(comp.id, by: importedCount);
    }

    await _computerRepository.updateLastDownload(comp.id);

    final newestFingerprint = selectNewestFingerprint(importedDives);
    if (newestFingerprint != null) {
      await _computerRepository.updateLastFingerprint(
        comp.id,
        newestFingerprint,
      );
    }
  }
}
