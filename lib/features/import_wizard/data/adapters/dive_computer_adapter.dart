import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart'
    show DiveDataSourcesCompanion, DiveProfilesCompanion;
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/data/services/fingerprint_utils.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
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

/// Signals that the confirm step can advance (user tapped Connect & Download).
final dcAdapterConfirmCanAdvanceProvider = StateProvider<bool>((ref) => false);

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
    WidgetRef? ref,
  }) : _importService = importService,
       _computerRepository = computerRepository,
       _diveRepository = diveRepository,
       _diverId = diverId,
       _knownComputer = knownComputer,
       _ref = ref,
       _displayName =
           displayName ?? knownComputer?.displayName ?? 'Dive Computer';

  final DiveImportService _importService;
  final DiveComputerRepository _computerRepository;
  final DiveRepository _diveRepository;
  final String _diverId;
  final DiveComputer? _knownComputer;
  final WidgetRef? _ref;
  final String _displayName;

  List<DownloadedDive> _downloadedDives = [];
  DiveComputer? _computer;
  String? _customDeviceName;

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
  /// computer is found, its [lastDiveFingerprint] enables incremental
  /// download (only new dives). Does NOT create a new computer record —
  /// that happens in [ensureComputer] after the download completes.
  Future<void> resolveKnownComputer(DiscoveredDevice device) async {
    if (computer != null) return;
    if (device.connectionType == DeviceConnectionType.ble ||
        device.connectionType == DeviceConnectionType.bluetoothClassic) {
      final existing = await _computerRepository.findByBluetoothAddress(
        device.address,
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
  Future<void> ensureComputer({
    required DiscoveredDevice device,
    String? serialNumber,
    String? firmwareVersion,
  }) async {
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
        label: 'Confirm',
        icon: Icons.check_circle,
        builder: (context) =>
            _ConfirmDeviceStep(adapter: this, onGoBack: goBackFromConfirm),
        canAdvance: dcAdapterConfirmCanAdvanceProvider,
        autoAdvance: true,
        hideBottomBar: true,
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

    // Merge and sort indices by startTime (oldest first) so sequential
    // dive number assignment produces correct chronological numbering.
    final allIndices = {...indicesToImport, ...indicesToConsolidate}.toList()
      ..sort((a, b) {
        final aTime = _downloadedDives[a].startTime;
        final bTime = _downloadedDives[b].startTime;
        return aTime.compareTo(bTime);
      });
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

    // Update computer metadata. Use ALL downloaded dives for the fingerprint
    // so skipped/consolidated dives aren't re-downloaded next session.
    await _updateComputerAfterImport(comp, imported, _downloadedDives);

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

// ---------------------------------------------------------------------------
// Confirm device step (discovery mode only)
// ---------------------------------------------------------------------------

/// Shows device info and lets the user name it before downloading.
class _ConfirmDeviceStep extends ConsumerStatefulWidget {
  const _ConfirmDeviceStep({required this.adapter, this.onGoBack});

  final DiveComputerAdapter adapter;
  final VoidCallback? onGoBack;

  @override
  ConsumerState<_ConfirmDeviceStep> createState() => _ConfirmDeviceStepState();
}

class _ConfirmDeviceStepState extends ConsumerState<_ConfirmDeviceStep> {
  late final TextEditingController _nameController;
  bool _resolved = false;
  bool _isKnownComputer = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkKnown());
  }

  Future<void> _checkKnown() async {
    if (!mounted) return;
    final discoveryState = ref.read(discoveryNotifierProvider);
    final device = discoveryState.selectedDevice;
    if (device != null) {
      await widget.adapter.resolveKnownComputer(device);
    }
    if (mounted) {
      setState(() {
        _isKnownComputer = widget.adapter.computer != null;
        _resolved = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onConnectAndDownload() {
    if (!_isKnownComputer) {
      widget.adapter.setCustomDeviceName(_nameController.text);
    }
    ref.read(dcAdapterConfirmCanAdvanceProvider.notifier).state = true;
  }

  void _onChooseDifferent() {
    ref.read(dcAdapterScanCanAdvanceProvider.notifier).state = false;
    ref.read(dcAdapterConfirmCanAdvanceProvider.notifier).state = false;
    widget.onGoBack?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    final discoveryState = ref.watch(discoveryNotifierProvider);
    final device = discoveryState.selectedDevice;
    if (device == null || !_resolved) {
      return const Center(child: CircularProgressIndicator());
    }

    final isRecognized = device.isRecognized;
    final knownComputer = widget.adapter.computer;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Device info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.bluetooth,
                      size: 40,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(device.displayName, style: theme.textTheme.titleLarge),
                  if (device.manufacturer != null)
                    Text(
                      device.manufacturer!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (_isKnownComputer && knownComputer != null)
            // Known computer badge
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Known Computer',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            'Saved as "${knownComputer.displayName}". '
                            'Only new dives will be downloaded.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Device name text field (new computer only)
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.diveComputer_discovery_deviceNameLabel,
                hintText: l10n.diveComputer_discovery_deviceNameHint(
                  device.model ?? 'Dive Computer',
                ),
                prefixIcon: const Icon(Icons.edit),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            // Recognized device badge
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      isRecognized
                          ? Icons.verified
                          : Icons.warning_amber_rounded,
                      color: isRecognized
                          ? colorScheme.primary
                          : colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRecognized
                                ? 'Recognized Device'
                                : 'Unknown Device',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: isRecognized
                                  ? colorScheme.primary
                                  : colorScheme.error,
                            ),
                          ),
                          Text(
                            isRecognized
                                ? 'This device is in our supported devices '
                                      'library. Dive download should work '
                                      'automatically.'
                                : 'This device may not be fully supported.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Connect & Download button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _onConnectAndDownload,
              icon: const Icon(Icons.download),
              label: Text(l10n.diveComputer_discovery_connectAndDownload),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            ),
          ),

          const SizedBox(height: 12),

          // Choose Different Device button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _onChooseDifferent,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
              child: Text(l10n.diveComputer_discovery_chooseDifferentDevice),
            ),
          ),
        ],
      ),
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
  bool _computerResolved = false;
  bool _noDives = false;

  @override
  void initState() {
    super.initState();
    // In discovery mode, check if the device matches a known computer
    // BEFORE the download starts. If found, the computer's fingerprint
    // enables incremental download (only new dives).
    if (widget.knownComputer != null) {
      _computerResolved = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolveComputer());
    }
  }

  Future<void> _resolveComputer() async {
    if (!mounted) return;
    final discoveryState = ref.read(discoveryNotifierProvider);
    final device = discoveryState.selectedDevice;
    if (device != null) {
      await widget.adapter.resolveKnownComputer(device);
    }
    if (mounted) setState(() => _computerResolved = true);
  }

  @override
  Widget build(BuildContext context) {
    // Listen for download completion to capture dives. Using ref.listen
    // (not ref.watch + build-time check) so stale DownloadPhase.complete
    // from a previous session is ignored — only fresh transitions trigger.
    ref.listen<DownloadState>(downloadNotifierProvider, (previous, next) {
      if (!_captured && next.phase == DownloadPhase.complete) {
        _captured = true;
        widget.adapter.setDownloadedDives(next.downloadedDives);

        // No new dives — show an informational message instead of advancing
        // to an empty Review step.
        if (next.downloadedDives.isEmpty) {
          if (mounted) setState(() => _noDives = true);
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;

          final discoveryState = ref.read(discoveryNotifierProvider);
          final device = discoveryState.selectedDevice;
          if (device != null) {
            await widget.adapter.ensureComputer(
              device: device,
              serialNumber: next.serialNumber,
              firmwareVersion: next.firmwareVersion,
            );
          }

          if (mounted) {
            ref.read(dcAdapterDownloadCanAdvanceProvider.notifier).state = true;
          }
        });
      }
    });

    // No new dives to import — show a terminal message.
    if (_noDives) {
      return _NoNewDivesView(onDone: () => context.pop());
    }

    // Wait for computer resolution before creating the download widget.
    // This ensures the fingerprint is available for incremental download.
    if (!_computerResolved) {
      return const Center(child: CircularProgressIndicator());
    }

    final discoveryState = ref.watch(discoveryNotifierProvider);
    var device = discoveryState.selectedDevice;
    final computer = widget.knownComputer ?? widget.adapter.computer;

    // For known-computer downloads, synthesize a DiscoveredDevice from the
    // computer's stored connection info when discovery state has no device.
    // The device descriptor lookup provides the dcModel integer that
    // libdivecomputer needs to select the right driver.
    if (device == null &&
        computer != null &&
        computer.bluetoothAddress != null) {
      final descriptorsAsync = ref.watch(deviceDescriptorsProvider);
      if (descriptorsAsync.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      final descriptors = descriptorsAsync.valueOrNull ?? [];
      final matchingDescriptor = descriptors
          .where(
            (d) =>
                d.vendor == computer.manufacturer &&
                d.product == computer.model,
          )
          .firstOrNull;

      device = DiscoveredDevice(
        id: computer.id,
        name: computer.displayName,
        connectionType: _connectionTypeFromString(computer.connectionType),
        address: computer.bluetoothAddress!,
        recognizedModel: matchingDescriptor != null
            ? DeviceModel.fromDescriptor(matchingDescriptor)
            : null,
        discoveredAt: DateTime.now(),
      );
    }

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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DeviceConnectionType _connectionTypeFromString(String? type) {
  switch (type?.toLowerCase()) {
    case 'bluetooth':
    case 'ble':
      return DeviceConnectionType.ble;
    case 'usb':
      return DeviceConnectionType.usb;
    case 'infrared':
      return DeviceConnectionType.infrared;
    default:
      return DeviceConnectionType.ble;
  }
}

// ---------------------------------------------------------------------------
// No new dives view
// ---------------------------------------------------------------------------

class _NoNewDivesView extends StatelessWidget {
  const _NoNewDivesView({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No new dives to download',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'All dives from this computer have already been imported.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}
