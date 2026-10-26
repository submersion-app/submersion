import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/computer_serial_identity.dart';
import 'package:submersion/features/dive_computer/data/repositories/dive_computer_connection_repository.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_computer/presentation/providers/dive_computer_connection_providers.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_computer/domain/services/reported_model_relabel.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/data/services/planned_dive_fill_service.dart';
import 'package:submersion/features/dive_computer/domain/services/planned_dive_matcher.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/data/services/fingerprint_utils.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    hide DiveMatchResult;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_source_details.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_number_conflict_notice.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';
import 'package:submersion/features/import_wizard/domain/models/diver_import_outcome.dart';
import 'package:submersion/features/import_wizard/domain/models/import_target_choice.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_auto_registrar.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_gear_linker.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_steps.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/downloaded_dive_summary.dart';

part 'dive_computer_adapter_connections.dart';
part 'dive_computer_adapter_import_steps.dart';
part 'dive_computer_adapter_target.dart';

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
class DiveComputerAdapter
    implements ImportSourceAdapter, RetargetableImportAdapter {
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
    PlannedDiveFillService? fillService,
    DiveComputerConnectionRepository? connectionRepository,
    Future<bool> Function()? followComputerOwner,
    DiverNameLookup? diverName,
    String? bindEquipmentId,
    TransmitterAutoRegistrar? transmitterRegistrar,
    TransmitterGearLinker? transmitterGearLinker,
    TransmitterRepository? transmitterRepository,
  }) : _bindEquipmentId = bindEquipmentId,
       _importService = importService,
       _transmitterRegistrar = transmitterRegistrar,
       _transmitterGearLinker = transmitterGearLinker,
       _transmitterRepository = transmitterRepository,
       _connectionRepository = connectionRepository,
       _computerRepository = computerRepository,
       _diveRepository = diveRepository,
       _consolidationService = consolidationService,
       _fillService =
           fillService ??
           PlannedDiveFillService(
             dives: diveRepository,
             computers: computerRepository,
             importService: importService,
             consolidation: consolidationService,
           ),
       _activeDiverId = diverId,
       _followComputerOwner = followComputerOwner,
       _diverName = diverName,
       _knownComputer = knownComputer,
       _ref = ref,
       _forceFullDownload = forceFullDownload,
       _displayName =
           displayName ?? knownComputer?.displayName ?? 'Dive Computer';

  final DiveImportService _importService;
  final DiveComputerRepository _computerRepository;
  final DiveRepository _diveRepository;
  final DiveConsolidationService _consolidationService;

  /// Where this download's connection is recorded (issue #3106). Read from
  /// [_ref] when not given, and absent in a bare test, which then records
  /// nothing.
  final DiveComputerConnectionRepository? _connectionRepository;
  DiveComputerConnectionRepository? get _connections =>
      _connectionRepository ??
      _ref?.read(diveComputerConnectionRepositoryProvider);

  /// The hand-added Dive Computer item "Connect and download" started from
  /// (issue #3676): a device seen for the first time is created on it.
  final String? _bindEquipmentId;

  /// The other item the discovered device already stands for, when it is not
  /// [_bindEquipmentId]'s. The device stays where it is and the summary says
  /// so; it is never rebound silently.
  String? _boundToOtherItemId;
  String? get boundToOtherItemId => _boundToOtherItemId;

  void _noteItemOf(DiveComputer existing) {
    final bind = _bindEquipmentId;
    final item = existing.equipmentId;
    if (bind != null && item != null && item != bind) {
      _boundToOtherItemId = item;
    }
  }

  /// The transmitter seams of a download (issue #3676): each new serial gets
  /// its item, every transmitter joins its dives, and the notice asks about
  /// each one not set up. Read from [_ref] when not given; absent in a bare
  /// test, which then registers nothing.
  final TransmitterAutoRegistrar? _transmitterRegistrar;
  final TransmitterGearLinker? _transmitterGearLinker;
  final TransmitterRepository? _transmitterRepository;
  TransmitterAutoRegistrar? get _registrar =>
      _transmitterRegistrar ?? _ref?.read(transmitterAutoRegistrarProvider);
  TransmitterGearLinker? get _gearLinker =>
      _transmitterGearLinker ?? _ref?.read(transmitterGearLinkerProvider);
  TransmitterRepository? get _transmitters =>
      _transmitterRepository ?? _ref?.read(transmitterRepositoryProvider);

  /// Fills planned dives from downloads (issue #2002).
  final PlannedDiveFillService _fillService;

  /// The profile that was active when the download started. A computer seen
  /// for the first time is registered to it.
  final String _activeDiverId;

  /// Whether a computer owned by another profile defaults to that profile
  /// (issue #2050); the diver's "Add downloads to the computer's owner",
  /// read from [_ref]'s settings when not given. Read when the target is
  /// resolved, so a wizard opened before settings load still honours it.
  final Future<bool> Function()? _followComputerOwner;

  /// Looks up a profile's name; read from [_ref] when not given.
  final DiverNameLookup? _diverName;

  /// The profile chosen for this download, or null for the active profile.
  String? _chosenDiverId;

  /// The computer's owner when it is another existing profile; see
  /// [DiveComputerAdapterTarget.resolveTarget].
  String? _ownerDiverId;

  /// Profile names already looked up, standing in when a later lookup fails.
  final Map<String, String> _diverNames = {};

  /// Send this download to [diverId]. The computer's owner does not change.
  @override
  Future<void> setTargetDiver(String diverId) async {
    _chosenDiverId = diverId;
    await _lookUpDiverName(diverId);
  }

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
  bool _downloadInterrupted = false;
  bool _deliversOldestFirst = false;
  DiveComputer? _computer;

  /// Whether [_computer] came from matching the discovered address rather
  /// than from the caller. An address is not identity: a USB port names the
  /// cable or the host, so [ensureComputer] re-checks it against the serial
  /// the download reports (issue #3106).
  bool _resolvedByAddress = false;
  String? _customDeviceName;
  DateTime? _sinceCutoff;

  // Session-level descriptor fields captured from the discovered device.
  String? _descriptorVendor;
  String? _descriptorProduct;
  int? _descriptorModel;
  String? _libdivecomputerVersion;

  /// What the last [ensureComputer] call was given, kept so [buildBundle]
  /// can retry the save when the download step's attempt failed.
  ({
    DiscoveredDevice device,
    String? serialNumber,
    String? firmwareVersion,
    String? reportedProduct,
    int? reportedModel,
  })?
  _pendingComputerSave;

  /// Why the last retry of [_pendingComputerSave] failed, reported by
  /// [performImport] in place of importing without a computer.
  Object? _computerSaveError;

  /// The download's clock sync answer, recorded once a retried save recovers
  /// the computer it belongs to. See [rememberClockSyncStatus].
  ClockSyncStatus? _pendingClockSyncStatus;

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
  /// Called by the download step widget when the download completes, or
  /// with [interrupted] set when the user keeps the dives a failed or
  /// cancelled download delivered. [deliversOldestFirst] says whether the
  /// backend sent them oldest-first; together they decide whether the import
  /// may move the saved fingerprint (see [selectResumeFingerprint]).
  /// Must be called before [buildBundle].
  void setDownloadedDives(
    List<DownloadedDive> dives, {
    bool interrupted = false,
    bool deliversOldestFirst = false,
  }) {
    _downloadedDives = List.unmodifiable(dives);
    _downloadInterrupted = interrupted;
    _deliversOldestFirst = deliversOldestFirst;
  }

  /// Set the first-sync cutoff captured from the download state.
  ///
  /// Dives at or before it default to skip in the review step (tier-1
  /// filter for backends that transferred them anyway). Pass null to clear
  /// it -- also done by [resetState].
  void setSinceCutoff(DateTime? cutoff) {
    _sinceCutoff = cutoff;
  }

  /// Keep the download's clock sync answer in case the computer save fails.
  ///
  /// The download step records the answer against the computer it just
  /// saved. When that save fails there is no computer id to record it
  /// against, so the adapter records it after a later retry recovers the
  /// computer (issue #2439).
  void rememberClockSyncStatus(ClockSyncStatus? status) {
    _pendingClockSyncStatus = status;
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
    if (_activeDiverId.isNotEmpty && await _resolveByLocalConnection(device)) {
      return;
    }
    if (device.connectionType == DeviceConnectionType.ble ||
        device.connectionType == DeviceConnectionType.bluetoothClassic) {
      if (_activeDiverId.isEmpty) return;
      final existing = await _findAcrossProfiles(
        (diverId) => _computerRepository.findByBluetoothAddress(
          device.address,
          diverId: diverId,
        ),
      );
      if (existing != null) {
        _computer = existing;
        _resolvedByAddress = true;
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
    String? reportedProduct,
    int? reportedModel,
  }) async {
    _pendingComputerSave = (
      device: device,
      serialNumber: serialNumber,
      firmwareVersion: firmwareVersion,
      reportedProduct: reportedProduct,
      reportedModel: reportedModel,
    );

    // Capture descriptor fields regardless of whether a computer record already
    // exists: these are always needed for the import service. A device that
    // named a different model during the download (issue #422) is stamped
    // with that one.
    final model = device.recognizedModel;
    final reported = reportedProduct?.trim();
    final hasReported =
        model != null &&
        reported != null &&
        reported.isNotEmpty &&
        reportedModel != null;
    if (model != null) {
      _descriptorVendor = model.manufacturer;
      _descriptorProduct = hasReported ? reported : model.model;
      _descriptorModel = hasReported ? reportedModel : model.dcModel;
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

    final connectionTypeStr = switch (device.connectionType) {
      DeviceConnectionType.ble => 'bluetooth',
      DeviceConnectionType.bluetoothClassic => 'bluetooth',
      DeviceConnectionType.usb => 'usb',
      DeviceConnectionType.infrared => 'infrared',
    };

    // A computer matched only by address that reports another serial was
    // the wrong match (two computers on one USB cable share a port): forget
    // it and identify the unit by its hardware instead.
    final resolved = _computer;
    if (resolved != null &&
        _resolvedByAddress &&
        _reportsAnotherComputer(resolved, device, serialNumber)) {
      _log.warning(
        '${device.address} matched ${resolved.displayName}, but the download '
        'reported serial ${serialNumber?.trim()}; matching by serial instead',
      );
      _computer = null;
      _resolvedByAddress = false;
    }

    if (computer case final known?) {
      _noteItemOf(known);
      await _recordDirectConnection(device, serialNumber);
      return;
    }

    // A BLE identifier is local to the host running this app. After a fresh
    // discovery, use the stable hardware identity to rebind this host's
    // identifier instead of creating a duplicate synced computer record.
    final normalizedSerial = serialNumber?.trim();
    final normalizedManufacturer = device.manufacturer?.trim();
    final scannedModel = device.model?.trim();
    final normalizedModel = hasReported ? reported : scannedModel;
    // Only the serial is required (#3106): a blank manufacturer or model on
    // either side is compatible, so a computer first registered by a file
    // import is found here too.
    if (normalizedSerial?.isNotEmpty == true) {
      var existing = await _findAcrossProfiles(
        (diverId) => _computerRepository.findByHardwareIdentity(
          manufacturer: normalizedManufacturer,
          model: normalizedModel,
          serialNumber: normalizedSerial!,
          diverId: diverId,
        ),
      );
      // A build before issue #422 saved the computer under the model it was
      // scanned as; find that record rather than creating a duplicate.
      if (existing == null &&
          hasReported &&
          scannedModel?.isNotEmpty == true &&
          scannedModel != normalizedModel) {
        existing = await _findAcrossProfiles(
          (diverId) => _computerRepository.findByHardwareIdentity(
            manufacturer: normalizedManufacturer,
            model: scannedModel!,
            serialNumber: normalizedSerial!,
            diverId: diverId,
          ),
        );
      }
      if (existing != null) {
        final rebound =
            relabelToReportedProduct(
              existing,
              hasReported ? reported : null,
            ).copyWith(
              serialNumber: normalizedSerial,
              firmwareVersion: firmwareVersion,
              connectionType: connectionTypeStr,
              bluetoothAddress: device.address,
            );
        await _computerRepository.updateComputer(rebound);
        _computer = rebound;
        _noteItemOf(rebound);
        await _recordDirectConnection(device, normalizedSerial);
        return;
      }
    }

    // Create a new computer record when the stable hardware identity is new.

    final newComputer =
        DiveComputer.create(
          id: const Uuid().v4(),
          // A reported model (issue #422) replaces the scan-time label.
          name:
              _customDeviceName ??
              (hasReported
                  ? '${device.manufacturer} $reported'
                  : device.displayName),
          diverId: _activeDiverId,
          manufacturer: device.manufacturer,
          model: hasReported ? reported : device.model,
        ).copyWith(
          serialNumber: serialNumber,
          firmwareVersion: firmwareVersion,
          connectionType: connectionTypeStr,
          bluetoothAddress: device.address,
          equipmentId: _bindEquipmentId,
        );

    _computer = await _computerRepository.createComputer(newComputer);
    await _recordDirectConnection(device, serialNumber);
  }

  // ---------------------------------------------------------------------------
  // ImportSourceAdapter interface
  // ---------------------------------------------------------------------------

  @override
  void resetState() {
    _sinceCutoff = null;
    _chosenDiverId = null;
    _ownerDiverId = null;
    _downloadInterrupted = false;
    _deliversOldestFirst = false;
    _pendingComputerSave = null;
    _computerSaveError = null;
    _boundToOtherItemId = null;
    _pendingClockSyncStatus = null;
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
    DuplicateAction.fillPlanned,
  };

  /// A dive computer download only ever produces dives, so there is no
  /// entity type that needs a narrower set than the adapter-wide one.
  @override
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      supportedDuplicateActions;

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

  /// Retries a computer save that failed on the download step (issue #2439).
  ///
  /// The download step lets the diver past that failure, so the adapter can
  /// reach [buildBundle] with no computer record. A failure is kept in
  /// [_computerSaveError] for [performImport] to report.
  Future<void> _retryPendingComputerSave() async {
    final pending = _pendingComputerSave;
    if (computer != null || pending == null) return;
    try {
      await ensureComputer(
        device: pending.device,
        serialNumber: pending.serialNumber,
        firmwareVersion: pending.firmwareVersion,
        reportedProduct: pending.reportedProduct,
        reportedModel: pending.reportedModel,
      );
      _computerSaveError = null;
    } catch (e, stackTrace) {
      _log.error(
        'Could not save ${pending.device.displayName} after its download',
        error: e,
        stackTrace: stackTrace,
      );
      _computerSaveError = e;
      return;
    }
    await _recordRecoveredClockSync();
  }

  /// Records the clock sync answer the download step could not, now that a
  /// retried save has produced a computer to record it against.
  Future<void> _recordRecoveredClockSync() async {
    final status = _pendingClockSyncStatus;
    final comp = computer;
    final ref = _ref;
    if (status == null || comp == null || ref == null) return;
    _pendingClockSyncStatus = null;
    try {
      await ref
          .read(clockSyncSettingsNotifierProvider.notifier)
          .recordSupport(comp.id, status);
    } catch (e, stackTrace) {
      _log.error(
        'Could not record clock sync support for ${comp.displayName}',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<ImportBundle> buildBundle() async {
    // Resolve the computer before the bundle records its id: duplicate
    // detection runs on this bundle next and keys its same-computer checks
    // (contained segments, cross-computer consolidation) on that id. A
    // failure here is left for performImport to report.
    await _retryPendingComputerSave();
    await resolveTarget();

    final items = _downloadedDives.map(_diveToEntityItem).toList();

    final cutoff = _sinceCutoff;
    final autoSkip = <int>{
      if (cutoff != null)
        for (var i = 0; i < _downloadedDives.length; i++)
          if (!_downloadedDives[i].startTime.isAfter(cutoff)) i,
    };

    return ImportBundle(
      source: ImportSourceInfo(
        type: ImportSourceType.diveComputer,
        displayName: _displayName,
        currentComputerId: computer?.id,
        details: diveComputerSourceDetails(
          customName: _customDeviceName,
          stored: computer,
          device: _pendingComputerSave?.device,
          serialNumber: _pendingComputerSave?.serialNumber,
          firmwareVersion: _pendingComputerSave?.firmwareVersion,
          reportedProduct: _pendingComputerSave?.reportedProduct,
        ),
      ),
      groups: {
        ImportEntityType.dives: EntityGroup(
          items: items,
          autoSkipIndices: autoSkip.isEmpty ? null : autoSkip,
        ),
      },
      targetChoice: _targetChoice,
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
      diverId: targetDiverId,
    );

    for (var i = 0; i < _downloadedDives.length; i++) {
      final dive = _downloadedDives[i];
      final result = await _importService.detectDuplicate(
        dive,
        diverId: targetDiverId,
        computerId: computer?.id,
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

    // Planned pass (issue #2002): downloads that matched nothing may fill a
    // planned dive of the target profile on the same local day. Runs after
    // the fingerprint, fuzzy and contained passes so a real duplicate never
    // becomes a fill. An empty diver id means an unscoped library, where
    // every planned dive is a candidate.
    final planned = await _diveRepository.getPlannedDives(
      diverId: targetDiverId.isEmpty ? null : targetDiverId,
    );
    if (planned.isNotEmpty) {
      final unmatched = [
        for (var i = 0; i < _downloadedDives.length; i++)
          if (!duplicateIndices.contains(i)) i,
      ];
      final pairs = const PlannedDiveMatcher().pair(
        incomingStarts: [
          for (final i in unmatched) _downloadedDives[i].startTime,
        ],
        plannedDives: planned,
      );
      for (final entry in pairs.entries) {
        final index = unmatched[entry.key];
        duplicateIndices.add(index);
        matchResults[index] = DiveMatchResult(
          diveId: entry.value,
          score: 1.0,
          timeDifferenceMs: 0,
          plannedDiveId: entry.value,
        );
      }
    }

    return bundle.copyWith(
      groups: {
        ...bundle.groups,
        ImportEntityType.dives: EntityGroup(
          items: diveGroup.items,
          duplicateIndices: duplicateIndices,
          matchResults: matchResults,
          autoSkipIndices: diveGroup.autoSkipIndices,
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
    // No retry here: duplicate detection already ran on this bundle, and if
    // the computer save failed in buildBundle it ran without the computer id.
    // Importing now would let the same-computer matches it missed through as
    // new dives, so report why the save failed instead.
    final comp = computer;
    final saveError = _computerSaveError;
    if (comp == null && saveError != null) {
      return UnifiedImportResult(
        importedCounts: const {},
        consolidatedCount: 0,
        skippedCount: 0,
        errorMessage: 'Could not save the dive computer: $saveError',
      );
    }
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

    // The import service outlives this run; start its unmatched-serial
    // accumulator fresh so an earlier session cannot leak into this notice.
    _importService.resetUnmatchedTransmitterSerials();

    // Build the final set of indices and track actions.
    final indicesToImport = <int>{};
    final indicesToConsolidate = <int>{};
    final indicesToReplaceSource = <int>{};
    final indicesToFillPlanned = <int>{};
    var skipped = 0;

    for (final index in baseSelections) {
      final action = diveActions[index];
      if (action == DuplicateAction.skip) {
        skipped++;
      } else if (action == DuplicateAction.consolidate) {
        indicesToConsolidate.add(index);
      } else if (action == DuplicateAction.replaceSource) {
        indicesToReplaceSource.add(index);
      } else if (action == DuplicateAction.fillPlanned) {
        indicesToFillPlanned.add(index);
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
      } else if (entry.value == DuplicateAction.fillPlanned &&
          !baseSelections.contains(entry.key)) {
        indicesToFillPlanned.add(entry.key);
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
          ...indicesToFillPlanned,
        }.toList()..sort((a, b) {
          final aTime = _downloadedDives[a].startTime;
          final bTime = _downloadedDives[b].startTime;
          return aTime.compareTo(bTime);
        });
    final total = allIndices.length;
    var imported = 0;
    var consolidated = 0;
    var updated = 0;
    var filled = 0;
    final fillOutcomes = <PlannedDiveFillOutcome>[];
    final filledDives = <DownloadedDive>{};
    var filledNameRoleDives = 0;
    final processedDives = <DownloadedDive>[];
    // Dives this run actually wrote (new, consolidated, kept standalone or
    // source-replaced); skipped duplicates never count toward a notice.
    final writtenDives = <DownloadedDive>[];
    final importedDiveIds = <String>[];

    for (var i = 0; i < allIndices.length; i++) {
      if (cancelToken?.isCancelled ?? false) break;

      final index = allIndices[i];
      if (index >= _downloadedDives.length) continue;

      final dive = _downloadedDives[index];

      // Fill a planned dive (issue #2002). The target rides on the match
      // result; a row whose target was cleared after selection, or whose
      // fill fails, imports as new instead so the download is never lost.
      String? plannedId;
      if (indicesToFillPlanned.contains(index)) {
        plannedId = bundle
            .groups[ImportEntityType.dives]
            ?.matchResults?[index]
            ?.plannedDiveId;
        if (plannedId != null) {
          try {
            final outcome = await _fillService.fill(
              plannedDiveId: plannedId,
              dive: dive,
              computerId: comp.id,
              descriptorVendor: _descriptorVendor,
              descriptorProduct: _descriptorProduct,
              descriptorModel: _descriptorModel,
              libdivecomputerVersion: _libdivecomputerVersion,
            );
            fillOutcomes.add(outcome);
            filled++;
            filledDives.add(dive);
            if (outcome.nameDerivedRoleTanks > 0) filledNameRoleDives++;
            importedDiveIds.add(plannedId);
            writtenDives.add(dive);
          } catch (e, st) {
            _log.error(
              'Fill of planned dive $plannedId failed; importing as new',
              error: e,
              stackTrace: st,
            );
            plannedId = null;
          }
        }
      }

      if (indicesToFillPlanned.contains(index) && plannedId != null) {
        // Filled above.
      } else if (indicesToConsolidate.contains(index)) {
        // Consolidate: add as secondary computer reading on matched dive.
        final diveGroup = bundle.groups[ImportEntityType.dives];
        final matchResult = diveGroup?.matchResults?[index];
        if (matchResult != null) {
          final result = await _consolidateDive(
            dive,
            matchResult.diveId,
            comp,
            // A dive the fold refuses is kept standalone, so it must carry
            // the same number an import-as-new would have given it.
            retainSourceDiveNumber: retainSourceDiveNumbers,
          );
          switch (result.outcome) {
            case _ConsolidateOutcome.consolidated:
              consolidated++;
              writtenDives.add(dive);
            case _ConsolidateOutcome.keptStandalone:
              // The fold refused, but the download survived as its own dive,
              // so it counts as imported. Reporting it as skipped would hide
              // a dive the fingerprint is about to advance past.
              imported++;
              writtenDives.add(dive);
              final keptId = result.diveId;
              if (keptId != null) importedDiveIds.add(keptId);
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
            diverId: targetDiverId,
            descriptorVendor: _descriptorVendor,
            descriptorProduct: _descriptorProduct,
            descriptorModel: _descriptorModel,
            libdivecomputerVersion: _libdivecomputerVersion,
          );
          updated++;
          writtenDives.add(dive);
        }
      } else {
        // Import as new dive. Use importSingleDiveAsNew to bypass the
        // service's internal duplicate detection — the wizard has already
        // resolved duplicates and the user's choice must be respected.
        final diveId = await _importService.importSingleDiveAsNew(
          dive,
          computerId: comp.id,
          diverId: targetDiverId,
          descriptorVendor: _descriptorVendor,
          descriptorProduct: _descriptorProduct,
          descriptorModel: _descriptorModel,
          libdivecomputerVersion: _libdivecomputerVersion,
          retainSourceDiveNumber: retainSourceDiveNumbers,
        );
        imported++;
        importedDiveIds.add(diveId);
        writtenDives.add(dive);
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

    // Queue a data-quality scan of the imported dives (fire-and-forget).
    scheduleQualityScan(importedDiveIds);
    scheduleSensorSummaryRefresh(importedDiveIds);
    scheduleDerivedMetricsRefresh(importedDiveIds);

    final unmatched = _importService.unmatchedTransmitterSerials;
    final needingSetup = await _registerTransmitters(unmatched, writtenDives);
    final needsSetupDives = _divesCarrying(needingSetup, writtenDives);
    // A fill skips the import service, so its own outcome says whether it
    // kept a role read off a transmitter's name.
    final nameRoleDives =
        _divesCarrying(unmatched, [
          for (final d in writtenDives)
            if (!filledDives.contains(d)) d,
        ], nameDerivedRolesOnly: true) +
        filledNameRoleDives;
    final numberConflict = await diveNumberConflictNotice(
      retainSourceDiveNumbers: retainSourceDiveNumbers,
      diveRepository: _diveRepository,
      importedDiveIds: importedDiveIds,
    );
    final diverOutcomes = await _diverOutcomes(importedDiveIds);
    return UnifiedImportResult(
      importedCounts: {ImportEntityType.dives: imported},
      consolidatedCount: consolidated,
      updatedCount: updated,
      filledCount: filled,
      fillOutcomes: fillOutcomes,
      skippedCount: skipped,
      // "View Dives" and the quality count work in the active profile, so a
      // download sent to another profile reports its dives only through
      // diverOutcomes, as a multi-profile file import does (issue #2050).
      importedDiveIds: diverOutcomes.isEmpty ? importedDiveIds : const [],
      diverOutcomes: diverOutcomes,
      notices: [
        // Counted over this download's dives: a transmitter not set up that
        // none of them carries is the inbox's to raise, not this summary's.
        if (needsSetupDives > 0)
          ImportNotice(
            kind: ImportNoticeKind.unknownTransmitter,
            count: needsSetupDives,
          ),
        if (_boundToOtherItemId case final other?)
          ImportNotice(
            kind: ImportNoticeKind.deviceBelongsToOtherItem,
            count: 1,
            targetId: other,
          ),
        if (nameRoleDives > 0)
          ImportNotice(
            kind: ImportNoticeKind.transmitterNameRoles,
            count: nameRoleDives,
          ),
        ?numberConflict,
      ],
    );
  }

  /// Registers each serial no registry row knows, puts every transmitter in
  /// this download on its dives, and returns the serials the notice asks
  /// about: new ones and any not set up (issue #3676). Best-effort: a failure
  /// leaves the download imported and falls back to the unmatched serials.
  Future<List<String>> _registerTransmitters(
    List<String> unmatched,
    List<DownloadedDive> written,
  ) async {
    final diverId = targetDiverId.isEmpty ? null : targetDiverId;
    try {
      // Every serial this download wrote, not just the import service's
      // unmatched ones: a planned-dive fill skips that service. The
      // registrar skips serials it already knows.
      final seen = {
        for (final dive in written)
          for (final tank in dive.tanks)
            ?normalizeTransmitterSerial(tank.transmitterSerial),
      };
      if (seen.isNotEmpty) {
        await _registrar?.registerNewSerials(seen, diverId: diverId);
        await _gearLinker?.linkSerials(seen, diverId: diverId);
      }
      final notSetUp =
          await _transmitters?.serialsNeedingSetup(diverId) ?? const {};
      return {...unmatched, ...notSetUp}.toList();
    } catch (e) {
      _log.warning('Transmitter registration failed (non-fatal): $e');
      return unmatched;
    }
  }

  /// How many of the dives this run wrote carry an unmatched serial. Skipped
  /// duplicates are not in [written], so they cannot inflate the count.
  ///
  /// With [nameDerivedRolesOnly], only a tank whose role the computer read
  /// off the transmitter's name counts (issue #2595). A matched serial's
  /// registry entry replaced that role on import, so the unmatched serials
  /// are exactly the ones still carrying it.
  int _divesCarrying(
    List<String> unmatched,
    List<DownloadedDive> written, {
    bool nameDerivedRolesOnly = false,
  }) {
    final set = unmatched.toSet();
    return written
        .where(
          (dive) => dive.tanks.any(
            (t) =>
                (!nameDerivedRolesOnly || t.roleSource != null) &&
                set.contains(normalizeTransmitterSerial(t.transmitterSerial)),
          ),
        )
        .length;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  EntityItem _diveToEntityItem(DownloadedDive dive) {
    final settings = _ref?.read(settingsProvider) ?? const AppSettings();
    final summary = formatDownloadedDiveSummary(dive, settings);

    final comp = computer;
    final diveData = IncomingDiveData.fromDownloadedDive(dive, computer: comp);

    return EntityItem(
      title: summary.title,
      subtitle: summary.subtitle,
      diveData: diveData,
    );
  }
}
