import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart'
    show DiveDataSourcesCompanion, DiveProfilesCompanion;
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/data/services/fingerprint_utils.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_step_widget.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/scan_step_widget.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    hide DiveMatchResult;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';

// ---------------------------------------------------------------------------
// Bridge providers
// ---------------------------------------------------------------------------

/// Signals that the scan step can advance (a device has been selected).
final dcAdapterScanCanAdvanceProvider = StateProvider<bool>((ref) => false);

/// Signals that the download step can advance (download is complete).
final dcAdapterDownloadCanAdvanceProvider = StateProvider<bool>((ref) => false);

// ---------------------------------------------------------------------------
// DiveComputerAdapter
// ---------------------------------------------------------------------------

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
  DiveComputerAdapter({
    required DiveImportService importService,
    required DiveComputerRepository computerRepository,
    required DiveRepository diveRepository,
    required String diverId,
    DiveComputer? knownComputer,
    String? displayName,
  }) : _importService = importService,
       _computerRepository = computerRepository,
       _diveRepository = diveRepository,
       _diverId = diverId,
       _knownComputer = knownComputer,
       _displayName =
           displayName ?? knownComputer?.displayName ?? 'Dive Computer';

  final DiveImportService _importService;
  final DiveComputerRepository _computerRepository;
  final DiveRepository _diveRepository;
  final String _diverId;
  final DiveComputer? _knownComputer;
  final String _displayName;

  List<DownloadedDive> _downloadedDives = [];
  DiveComputer? _computer;

  /// Whether this adapter was created for a known (previously paired) computer.
  bool get isKnownComputer => _knownComputer != null;

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

  // ---------------------------------------------------------------------------
  // ImportSourceAdapter interface
  // ---------------------------------------------------------------------------

  @override
  ImportSourceType get sourceType => ImportSourceType.diveComputer;

  @override
  String get displayName => _displayName;

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
    DuplicateAction.consolidate,
  };

  @override
  List<WizardStepDef> get acquisitionSteps {
    if (isKnownComputer) {
      return [
        WizardStepDef(
          label: 'Download',
          icon: Icons.download,
          builder: (context) => _AdapterDownloadStep(
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
        builder: (context) => _AdapterScanStep(adapter: this),
        canAdvance: dcAdapterScanCanAdvanceProvider,
        autoAdvance: true,
      ),
      WizardStepDef(
        label: 'Download',
        icon: Icons.download,
        builder: (context) => _AdapterDownloadStep(adapter: this),
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

    for (var i = 0; i < _downloadedDives.length; i++) {
      final dive = _downloadedDives[i];
      final result = await _importService.detectDuplicate(dive);

      if (result.isDuplicate && result.score >= 0.5) {
        duplicateIndices.add(i);
        matchResults[i] = DiveMatchResult(
          diveId: result.matchingDiveId!,
          score: result.score,
          timeDifferenceMs: (result.timeDifferenceSeconds ?? 0) * 1000,
          depthDifferenceMeters: result.depthDifferenceMeters,
          durationDifferenceSeconds: null,
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
    void Function(String phase, int current, int total)? onProgress,
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
    var skipped = 0;

    for (final index in baseSelections) {
      final action = diveActions[index];
      if (action == DuplicateAction.skip) {
        skipped++;
      } else if (action == DuplicateAction.consolidate) {
        indicesToConsolidate.add(index);
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
      } else if (entry.value == DuplicateAction.skip &&
          !baseSelections.contains(entry.key)) {
        skipped++;
      }
    }

    // Merge and sort all indices for progress tracking.
    final allIndices = {...indicesToImport, ...indicesToConsolidate}.toList()
      ..sort();
    final total = allIndices.length;
    var imported = 0;
    var consolidated = 0;
    final importedDives = <DownloadedDive>[];
    final importedDiveIds = <String>[];

    for (var i = 0; i < allIndices.length; i++) {
      final index = allIndices[i];
      if (index >= _downloadedDives.length) continue;

      final dive = _downloadedDives[index];

      if (indicesToConsolidate.contains(index)) {
        // Consolidate: add as secondary computer reading on matched dive.
        final diveGroup = bundle.groups[ImportEntityType.dives];
        final matchResult = diveGroup?.matchResults?[index];
        if (matchResult != null) {
          await _consolidateDive(dive, matchResult.diveId, comp);
          consolidated++;
        }
      } else {
        // Import as new dive.
        final importResult = await _importService.importDives(
          dives: [dive],
          computer: comp,
          mode: ImportMode.all,
          defaultResolution: ConflictResolution.importAsNew,
          diverId: _diverId,
        );
        imported++;
        importedDives.add(dive);
        importedDiveIds.addAll(importResult.importedDiveIds);
      }

      onProgress?.call('Dives', i + 1, total);
    }

    // Update computer metadata after import.
    await _updateComputerAfterImport(comp, imported, importedDives);

    return UnifiedImportResult(
      importedCounts: {ImportEntityType.dives: imported},
      consolidatedCount: consolidated,
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

    final depthStr = dive.maxDepth.toStringAsFixed(1);
    final durationMin = dive.duration.inMinutes;
    final tempStr = dive.minTemperature != null
        ? ' \u00b7 ${dive.minTemperature!.toStringAsFixed(1)}\u00b0C'
        : '';
    final subtitle = '${depthStr}m max \u00b7 $durationMin min$tempStr';

    final comp = computer;
    final diveData = IncomingDiveData.fromDownloadedDive(dive, computer: comp);

    return EntityItem(title: title, subtitle: subtitle, diveData: diveData);
  }

  /// Consolidate a downloaded dive as a secondary computer reading on an
  /// existing dive.
  Future<void> _consolidateDive(
    DownloadedDive dive,
    String targetDiveId,
    DiveComputer comp,
  ) async {
    const uuid = Uuid();
    final now = DateTime.now();

    final secondaryReading = DiveDataSourcesCompanion.insert(
      id: uuid.v4(),
      diveId: targetDiveId,
      isPrimary: const Value(false),
      computerModel: Value(comp.model),
      computerSerial: Value(comp.serialNumber),
      sourceFormat: const Value('dive_computer'),
      maxDepth: Value(dive.maxDepth),
      avgDepth: Value(dive.avgDepth),
      duration: Value(dive.durationSeconds),
      waterTemp: Value(dive.minTemperature),
      entryTime: Value(dive.startTime),
      exitTime: Value(dive.endTime),
      importedAt: now,
      createdAt: now,
    );

    final secondaryProfile = dive.profile
        .map(
          (p) => DiveProfilesCompanion.insert(
            id: uuid.v4(),
            diveId: targetDiveId,
            isPrimary: const Value(false),
            timestamp: p.timeSeconds,
            depth: p.depth,
            temperature: Value(p.temperature),
            pressure: Value(p.pressure),
            setpoint: Value(p.setpoint),
            ppO2: Value(p.ppo2),
          ),
        )
        .toList();

    await _diveRepository.consolidateComputer(
      targetDiveId: targetDiveId,
      secondaryReading: secondaryReading,
      secondaryProfile: secondaryProfile,
    );
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

// =============================================================================
// Private step widgets
// =============================================================================

/// Wraps the existing [ScanStepWidget] for use in the wizard acquisition flow.
///
/// Sets the [dcAdapterScanCanAdvanceProvider] when a device is selected.
class _AdapterScanStep extends ConsumerWidget {
  const _AdapterScanStep({required this.adapter});

  final DiveComputerAdapter adapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScanStepWidget(
      onDeviceSelected: (device) {
        ref.read(discoveryNotifierProvider.notifier).selectDevice(device);
        // Reset then set so the provider transitions false -> true,
        // enabling auto-advance even when re-selecting a device.
        ref.read(dcAdapterScanCanAdvanceProvider.notifier).state = false;
        ref.read(dcAdapterScanCanAdvanceProvider.notifier).state = true;
      },
    );
  }
}

/// Wraps the existing [DownloadStepWidget] for the wizard acquisition flow.
///
/// Listens to [downloadNotifierProvider] for completion. When the download
/// finishes, the downloaded dives are stored in the adapter (not auto-imported)
/// and [dcAdapterDownloadCanAdvanceProvider] is set to true.
class _AdapterDownloadStep extends ConsumerStatefulWidget {
  const _AdapterDownloadStep({required this.adapter, this.knownComputer});

  final DiveComputerAdapter adapter;
  final DiveComputer? knownComputer;

  @override
  ConsumerState<_AdapterDownloadStep> createState() =>
      _AdapterDownloadStepState();
}

class _AdapterDownloadStepState extends ConsumerState<_AdapterDownloadStep> {
  bool _captured = false;

  @override
  Widget build(BuildContext context) {
    // Watch the download state to capture dives on completion.
    final downloadState = ref.watch(downloadNotifierProvider);

    if (!_captured && downloadState.phase == DownloadPhase.complete) {
      _captured = true;
      // Store downloaded dives in the adapter for buildBundle.
      widget.adapter.setDownloadedDives(downloadState.downloadedDives);

      // Signal that the wizard can advance.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(dcAdapterDownloadCanAdvanceProvider.notifier).state = true;
        }
      });
    }

    final discoveryState = ref.watch(discoveryNotifierProvider);
    final device = discoveryState.selectedDevice;
    final computer = widget.knownComputer ?? widget.adapter.computer;

    return DownloadStepWidget(
      device: device,
      computer: computer,
      onComplete: () {
        // Handled by the state watcher above.
      },
      onError: (error) {
        // Download errors are shown by the DownloadStepWidget itself.
      },
    );
  }
}
