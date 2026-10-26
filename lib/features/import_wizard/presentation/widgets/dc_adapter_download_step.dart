import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/dive_computer/data/services/fingerprint_utils.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/domain/services/known_computer_reacquisition.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_step_widget.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/scan_step_widget.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_another_unit_view.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_known_computer_not_found_view.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_no_direct_download_view.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_no_new_dives_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class DcAdapterDownloadStep extends ConsumerStatefulWidget {
  const DcAdapterDownloadStep({
    super.key,
    required this.adapter,
    this.knownComputer,
  });

  final DiveComputerAdapter adapter;
  final DiveComputer? knownComputer;

  /// How long a saved-computer download scans for the computer's stored
  /// address before settling for the only device of the same model, or
  /// failing that, a direct connect with the stored address. With no address
  /// on this device it is the whole search for that one device (issue
  /// #3710). Matches the first resolve attempt of the macOS/iOS native
  /// resolver.
  static const knownDeviceScanTimeout = Duration(seconds: 15);

  @override
  ConsumerState<DcAdapterDownloadStep> createState() =>
      _DcAdapterDownloadStepState();
}

class _DcAdapterDownloadStepState extends ConsumerState<DcAdapterDownloadStep> {
  static final LoggerService _log = LoggerService.forClass(
    DcAdapterDownloadStep,
  );

  bool _captured = false;
  bool _computerResolved = false;

  /// Whether the adapter has worked out which profile the download goes to,
  /// for the first-sync cutoff default (issue #2050): null before it starts,
  /// false while it runs, true once done.
  bool? _targetResolved;

  /// The device handed to the download, when the step built it from the
  /// saved computer rather than taking a discovery selection. Completion
  /// bookkeeping (saving the computer, recording its connection and clock
  /// sync answer) needs the device the download actually used (#3106).
  DiscoveredDevice? _downloadDevice;
  bool _searchingForKnownDevice = false;
  bool _noDives = false;

  /// Whether a search by make and model for a saved Bluetooth computer with
  /// no address on this device found no device, or several (issue #3710).
  bool _notFoundNearby = false;

  /// Whether that search ran its full length; false means Bluetooth was
  /// off, not allowed, or the scan failed.
  bool _searchRanFull = true;

  /// Whether the download goes to a same-model stand-in rather than a device
  /// carrying the saved address, so its serial must confirm it.
  bool _adoptedStandIn = false;

  /// The serial a stand-in reported that is not the saved computer's: it was
  /// another unit, and none of its dives are imported.
  String? _anotherUnitSerial;

  /// The discovery notifier whose scan this step started to re-acquire a
  /// saved computer and still owes a stop: the scan runs on through the
  /// connect, as it does in the scan-and-download flow (issue #3369), and
  /// ends once the download is over or the step closes.
  DiscoveryNotifier? _ownedScan;

  @override
  void dispose() {
    _releaseScan();
    super.dispose();
  }

  /// Stops the re-acquire scan if this step still owns one.
  void _releaseScan() {
    final notifier = _ownedScan;
    if (notifier == null) return;
    _ownedScan = null;
    logFailure(
      notifier.stopScan(),
      DcAdapterDownloadStep,
      'stop the re-acquire scan',
    );
  }

  @override
  void initState() {
    super.initState();
    final computer = widget.knownComputer;
    if (computer == null) {
      // In discovery mode, check if the device matches a known computer
      // BEFORE the download starts. If found, the computer's fingerprint
      // enables incremental download (only new dives).
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolveComputer());
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reacquireKnownDevice(computer),
      );
    }
  }

  /// Re-acquires a saved Bluetooth computer by scanning for its stored
  /// address before the download connects (issue #1232).
  ///
  /// Connecting straight to a stored address fails on Android and Windows
  /// unless the stack has recently seen the device advertise, which is why
  /// the scan-and-download flow worked for the same computer while the
  /// saved entry did not.
  ///
  /// The stored address is host-local and can go stale: iOS mints a new
  /// CoreBluetooth identifier when a computer rotates its Bluetooth address,
  /// after which nothing ever advertises the stored one (issue #1423). So
  /// when the scan times out without seeing it, the step downloads from the
  /// only device recognized as the same make and model, if there is exactly
  /// one; a successful download then rewrites the stored address. With no
  /// such device, or more than one, the step falls back to the stored
  /// address exactly as before.
  ///
  /// The scan is left running through the connect (issue #3369): Android
  /// connected a saved Shearwater only from the scan-and-download flow,
  /// whose scan is still running when it connects, while this path used to
  /// stop its scan the moment the address advertised and connect straight
  /// after. [_releaseScan] stops it.
  Future<void> _reacquireKnownDevice(DiveComputer computer) async {
    if (!mounted) return;
    final address = computer.bluetoothAddress;
    final notifier = ref.read(discoveryNotifierProvider.notifier);
    final selected = ref.read(discoveryNotifierProvider).selectedDevice;
    final alreadyAcquired =
        selected != null &&
        address != null &&
        bluetoothAddressesMatch(selected.address, address);
    // A saved computer downloads only from a device carrying its stored
    // address. A selection left over from an earlier discovery session is
    // dropped from the provider itself, because the completion path reads
    // the provider's selection to capture the descriptor the import
    // service records; hiding it locally here would not be enough.
    if (selected != null && !alreadyAcquired) {
      notifier.clearSelectedDevice();
    }
    final isBluetooth =
        _connectionTypeFromString(computer.connectionType) ==
        DeviceConnectionType.ble;

    // Saved on another device: the Bluetooth connection synced, its
    // per-device address did not (issue #3710). A missing type is not
    // evidence of Bluetooth here, since a file-imported record has neither.
    // Native discovery scans BLE only, so a Bluetooth Classic computer could
    // never turn up and keeps the no-direct-download explanation.
    if (address == null &&
        computer.connectionType != null &&
        isBluetooth &&
        canFindByModel(computer)) {
      await _findByModel(computer);
      return;
    }

    if (address == null || !isBluetooth || alreadyAcquired) {
      setState(() => _computerResolved = true);
      return;
    }

    setState(() => _searchingForKnownDevice = true);
    _ownedScan = notifier;
    var device = await notifier.scanForAddress(
      address,
      timeout: DcAdapterDownloadStep.knownDeviceScanTimeout,
      stopScanWhenDone: false,
    );
    // Closed while scanning: nothing here should download. Dispose stopped
    // the scan, but on Android the scan only starts once the permission
    // prompt returns, which can be after the step closed, so stop it again.
    if (!mounted) {
      logFailure(
        notifier.stopScan(),
        DcAdapterDownloadStep,
        'stop the re-acquire scan',
      );
      return;
    }
    if (device != null) {
      _log.info(
        'Re-acquired ${computer.displayName} at ${device.address}; keeping '
        'the scan running through the connect',
        category: LogCategory.bluetooth,
      );
    } else {
      device = _sameModelFallback(computer, address);
      _adoptedStandIn = device != null;
    }
    if (device != null) notifier.selectDevice(device);
    setState(() {
      _searchingForKnownDevice = false;
      _computerResolved = true;
    });
  }

  /// Looks for a saved Bluetooth computer with no address on this device by
  /// its make and model (issue #3710).
  ///
  /// The address is a per-device identifier that never syncs, so a computer
  /// saved on a Mac reaches a phone with nothing to scan for. The scan runs
  /// its full length, because only then can it say that exactly one device
  /// of the saved model is nearby; a successful download then records this
  /// device's address, once the serial it reports confirms the match. With
  /// none, or several, the step says so and offers to search again.
  Future<void> _findByModel(DiveComputer computer) async {
    final notifier = ref.read(discoveryNotifierProvider.notifier);
    setState(() {
      _searchingForKnownDevice = true;
      _notFoundNearby = false;
    });
    _ownedScan = notifier;
    final ranFull = await notifier.scanForWindow(
      timeout: DcAdapterDownloadStep.knownDeviceScanTimeout,
      stopScanWhenDone: false,
    );
    if (!mounted) {
      logFailure(
        notifier.stopScan(),
        DcAdapterDownloadStep,
        'stop the re-acquire scan',
      );
      return;
    }
    // A window cut short cannot say that only one such device is nearby.
    final device = ranFull ? _sameModelFallback(computer, null) : null;
    if (!ranFull) {
      _log.warning(
        'The search for ${computer.displayName} ended before its window: '
        'Bluetooth is off, not allowed, or the scan failed',
        category: LogCategory.bluetooth,
      );
    }
    if (device != null) {
      _adoptedStandIn = true;
      notifier.selectDevice(device);
    } else {
      // Awaited, so a Try Again tapped next cannot start a scan that this
      // stop then marks as finished.
      _ownedScan = null;
      try {
        await notifier.stopScan();
      } catch (e, stackTrace) {
        _log.error(
          'Could not stop the search for ${computer.displayName}',
          category: LogCategory.bluetooth,
          error: e,
          stackTrace: stackTrace,
        );
      }
      if (!mounted) return;
    }
    setState(() {
      _searchingForKnownDevice = false;
      _notFoundNearby = device == null;
      _searchRanFull = ranFull;
      _computerResolved = true;
    });
  }

  /// Starts the search by make and model over after it found nothing. A
  /// second tap before the view rebuilds finds the search already running.
  void _retryFindByModel(DiveComputer computer) {
    if (_searchingForKnownDevice) return;
    setState(() => _computerResolved = false);
    unawaited(_findByModel(computer));
  }

  /// The one device of [computer]'s make and model the scan saw while the
  /// stored [address] stayed silent, or null. With no [address] this device
  /// holds none for the computer, and the scan looked for the model alone.
  ///
  /// Only a scan that actually ran can answer this. `scanForAddress` also
  /// resolves with null when the scan never started, in which case the
  /// discovered list still holds whatever an earlier scan left in the
  /// provider, and adopting a device from it would download from something
  /// this attempt never saw. An error message on the discovery state is
  /// exactly that signal: a scan that starts clears it.
  DiscoveredDevice? _sameModelFallback(DiveComputer computer, String? address) {
    final discovery = ref.read(discoveryNotifierProvider);
    final scanError = discovery.errorMessage;
    final target = address ?? 'its make and model';
    if (scanError != null) {
      _log.warning(
        'Not looking for a same-model stand-in for ${computer.displayName}: '
        'the scan for $target did not run ($scanError)',
        category: LogCategory.bluetooth,
      );
      return null;
    }
    final device = sameModelFallbackDevice(
      computer: computer,
      discovered: discovery.discoveredDevices,
    );
    if (device != null) {
      final why = address == null
          ? 'No address on this device for ${computer.displayName}'
          : 'Stored address $address for ${computer.displayName} did not '
                'advertise';
      _log.info(
        '$why; downloading from the only ${device.displayName} seen, '
        '${device.name} (${device.address})',
        category: LogCategory.bluetooth,
      );
    } else if (address == null) {
      _log.info(
        'No address on this device for ${computer.displayName}, and the '
        'scan saw no single ${computer.displayName} to download from',
        category: LogCategory.bluetooth,
      );
    }
    return device;
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
        _captureAndAdvance(next);
      }
    });

    final anotherUnit = _anotherUnitSerial;
    final savedComputer = widget.knownComputer ?? widget.adapter.computer;
    if (anotherUnit != null && savedComputer != null) {
      return DcAnotherUnitView(
        computer: savedComputer,
        reportedSerial: anotherUnit,
        onDone: () => context.pop(),
      );
    }

    // No new dives to import — show a terminal message.
    if (_noDives) {
      return DcNoNewDivesView(onDone: () => context.pop());
    }

    // Wait for computer resolution before creating the download widget.
    // This ensures the fingerprint is available for incremental download.
    if (!_computerResolved) {
      final knownComputer = widget.knownComputer;
      if (_searchingForKnownDevice && knownComputer != null) {
        return _KnownDeviceSearchView(computer: knownComputer);
      }
      return const Center(child: CircularProgressIndicator());
    }

    final discoveryState = ref.watch(discoveryNotifierProvider);
    var device = discoveryState.selectedDevice;
    final computer = widget.knownComputer ?? widget.adapter.computer;

    final knownComputer = widget.knownComputer;
    if (_notFoundNearby && knownComputer != null) {
      return DcKnownComputerNotFoundView(
        computer: knownComputer,
        // A scan that starts clears the error flag; one that could not keeps
        // it once stopped.
        problem: _searchRanFull
            ? null
            : discoveryState.bluetoothUnavailable
            ? DcSearchProblem.bluetoothOff
            : DcSearchProblem.couldNotScan,
        onRetry: () => _retryFindByModel(knownComputer),
        onDone: () => context.pop(),
      );
    }

    // A USB computer saved on a desktop syncs here, but iOS has no USB host
    // (issue #2837). Sync strips the host-local port, so the synced copy has
    // no stored address and must be recognized by its connection type alone;
    // with an address it would fail in the native layer with "No USB serial
    // ports found". A Garmin keeps its FIT-file guidance inside the view.
    if (device == null &&
        computer != null &&
        !ScanStepWidget.offersUsb &&
        _connectionTypeFromString(computer.connectionType) ==
            DeviceConnectionType.usb) {
      return DcNoDirectDownloadView(
        computer: computer,
        reason: DcNoDirectDownloadReason.usbUnavailable,
        onImportFromFile: () => context.push('/transfer/import-wizard'),
        onDone: () => context.pop(),
      );
    }

    // For known-computer downloads, synthesize a DiscoveredDevice from the
    // computer's stored connection info when discovery state has no device.
    // The device descriptor lookup provides the dcModel integer that
    // libdivecomputer needs to select the right driver.
    final storedTransport = _connectionTypeFromString(computer?.connectionType);
    if (device == null &&
        computer != null &&
        computer.bluetoothAddress != null &&
        storedTransport != null) {
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
        connectionType: storedTransport,
        address: computer.bluetoothAddress!,
        recognizedModel: matchingDescriptor != null
            ? DeviceModel.fromDescriptor(matchingDescriptor)
            : null,
        discoveredAt: DateTime.now(),
      );
    }

    // A saved computer with no stored address (a Garmin watch, or any
    // computer that came from a file or cloud import) leaves nothing to
    // connect to. DownloadStepWidget silently never starts without a device,
    // which spun on "Preparing..." forever (issue #1858); explain instead.
    if (device == null && computer != null) {
      return DcNoDirectDownloadView(
        computer: computer,
        onImportFromFile: () => context.push('/transfer/import-wizard'),
        onDone: () => context.pop(),
      );
    }

    // The first-sync cutoff prompt only ever applies when this computer has
    // no stored fingerprint yet and the caller isn't forcing a full
    // re-download -- in every other case the default's value is irrelevant.
    // Only wait on the provider when it could matter: firstSyncCutoffDefault
    // is a FutureProvider backed by a real Drift query, so the very first
    // watch always yields AsyncLoading (valueOrNull == null) synchronously.
    // If DownloadStepWidget were constructed immediately with that
    // transient null, its initState would read "no cutoff" and
    // unconditionally auto-start the download before the query resolves;
    // the later rebuild with the real value could arrive after the
    // download already started (or, worse, after this widget's state
    // already decided not to show the prompt), silently skipping it.
    // Gating here -- the same pattern already used above for
    // _computerResolved and deviceDescriptorsProvider -- ensures
    // DownloadStepWidget only ever sees the final, settled value.
    final promptCouldApply =
        computer?.lastDiveFingerprint == null &&
        !widget.adapter.forceFullDownload;
    DateTime? cutoffDefault;
    if (promptCouldApply) {
      // The default comes from the log the download will go to, which
      // may be the computer owner's (issue #2050); work that out first.
      if (_targetResolved != true && widget.adapter.mayBelongToAnotherProfile) {
        if (_targetResolved == null) {
          _targetResolved = false;
          widget.adapter.resolveTarget().whenComplete(() {
            if (mounted) setState(() => _targetResolved = true);
          });
        }
        return const Center(child: CircularProgressIndicator());
      }
      final cutoffAsync = ref.watch(
        firstSyncCutoffDefaultProvider(widget.adapter.targetDiverId),
      );
      if (cutoffAsync.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      // A diver with an empty log (or no active diver) resolves to null
      // here and falls through to the normal auto-start path below --
      // this branch never hangs once the future settles, error or not.
      cutoffDefault = cutoffAsync.valueOrNull;
    }

    _downloadDevice = device;
    return DownloadStepWidget(
      device: device,
      computer: computer,
      forceFullDownload: widget.adapter.forceFullDownload,
      firstSyncCutoffDefault: cutoffDefault,
      onComplete: () {
        // Handled by the state watcher above.
      },
      onError: (error) {
        // Download errors are shown by the DownloadStepWidget itself.
      },
      // The user chose to keep the dives delivered before an interrupted
      // download.
      onImportPartial: () => unawaited(_importPartial(device)),
    );
  }

  /// Captures an interrupted download's dives, telling the adapter whether
  /// the backend delivered them oldest-first.
  ///
  /// Only then (Shearwater Petrel, issue #480) are they the oldest run of new
  /// dives, so that importing them may move the resume point. A newest-first
  /// backend delivered the newest dives and skipped older ones, which a moved
  /// resume point would hide for good (issue #2902). The order comes from the
  /// native descriptor catalog; when it cannot be read, newest-first is
  /// assumed, which at worst re-offers these dives next time.
  Future<void> _importPartial(DiscoveredDevice? device) async {
    // The dives to keep are the ones on screen now. Retry stays enabled
    // during the lookup below, and a retry replaces this state.
    final snapshot = ref.read(downloadNotifierProvider);
    var descriptors = const <pigeon.DeviceDescriptor>[];
    try {
      descriptors = await ref.read(deviceDescriptorsProvider.future);
    } catch (e, stackTrace) {
      _log.error(
        'Could not read the descriptor catalog; treating the partial '
        'download as newest-first',
        error: e,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    // A retry started while the catalog was read: that attempt now owns the
    // step, and capturing here would also block its own completion. A retry
    // always starts a new phase and a fresh dive list.
    final current = ref.read(downloadNotifierProvider);
    if (current.phase != snapshot.phase ||
        !identical(current.downloadedDives, snapshot.downloadedDives)) {
      return;
    }
    _captureAndAdvance(
      snapshot,
      interrupted: true,
      deliversOldestFirst: modelDeliversOldestFirst(
        descriptors,
        device?.recognizedModel,
      ),
    );
  }

  /// Captures the downloaded dives into the adapter and advances the wizard to
  /// the Review step. Shared by the normal completion path and the
  /// import-partial action for an interrupted download.
  void _captureAndAdvance(
    DownloadState state, {
    bool interrupted = false,
    bool deliversOldestFirst = false,
  }) {
    if (_captured) return;
    _captured = true;
    _releaseScan();

    // A same-model stand-in that reports another serial is another unit,
    // such as a buddy's: none of its dives belong in this log (#3710).
    final reported = state.serialNumber?.trim() ?? '';
    final usedDevice =
        ref.read(discoveryNotifierProvider).selectedDevice ?? _downloadDevice;
    if (_adoptedStandIn &&
        usedDevice != null &&
        widget.adapter.reportsAnotherUnit(usedDevice, reported)) {
      _log.warning(
        '${usedDevice.address} reported serial $reported, not the saved '
        "computer's; importing none of its dives",
        category: LogCategory.bluetooth,
      );
      ref.read(discoveryNotifierProvider.notifier).clearSelectedDevice();
      if (mounted) setState(() => _anotherUnitSerial = reported);
      return;
    }
    widget.adapter.setSinceCutoff(state.sinceCutoff);
    widget.adapter.setDownloadedDives(
      state.downloadedDives,
      interrupted: interrupted,
      deliversOldestFirst: deliversOldestFirst,
    );

    // No dives — show an informational message instead of advancing to an
    // empty Review step. The computer itself is still saved below: reaching
    // this point means it paired, connected and completed a download, which is
    // exactly what makes it worth remembering for next time. Returning early
    // here used to strand a working computer as unknown whenever the diver's
    // first download had nothing new on it (issue #865).
    final hasDives = state.downloadedDives.isNotEmpty;
    if (!hasDives && mounted) {
      setState(() => _noDives = true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Saving the computer and noting its clock sync answer are bookkeeping:
      // the dives are already in hand. Each failure is logged and swallowed so
      // it cannot skip the can-advance flip below, which is what left the
      // wizard on "Download complete" with Next disabled (issue #2439).
      final discoveryState = ref.read(discoveryNotifierProvider);
      final device = discoveryState.selectedDevice ?? _downloadDevice;
      if (device != null) {
        // If the save below fails, the adapter records this once a later
        // retry recovers the computer.
        widget.adapter.rememberClockSyncStatus(state.clockSyncStatus);

        // Serial and firmware ride on the completion event, not on the dives,
        // so the hardware-identity rebind still works with an empty download.
        try {
          await widget.adapter.ensureComputer(
            device: device,
            serialNumber: state.serialNumber,
            firmwareVersion: state.firmwareVersion,
            reportedProduct: state.reportedProduct,
            reportedModel: state.reportedModel,
          );
        } catch (e, stackTrace) {
          _log.error(
            'Could not save ${device.displayName} after its download; '
            'continuing without a computer record',
            category: LogCategory.database,
            error: e,
            stackTrace: stackTrace,
          );
        }
        if (!mounted) return;

        // Remember what the model answered about clock sync so the detail
        // page can say so (issue #1216). ensureComputer resolved the
        // computer in both the first-download and known-computer flows, so
        // this one site covers every download.
        final computer = widget.adapter.computer;
        final clockSyncStatus = state.clockSyncStatus;
        if (computer != null && clockSyncStatus != null) {
          try {
            await ref
                .read(clockSyncSettingsNotifierProvider.notifier)
                .recordSupport(computer.id, clockSyncStatus);
          } catch (e, stackTrace) {
            _log.error(
              'Could not record clock sync support for '
              '${computer.displayName}',
              category: LogCategory.app,
              error: e,
              stackTrace: stackTrace,
            );
          }
          if (!mounted) return;
        }
      }

      // Only a download that actually produced dives has a Review step to
      // advance to; the empty case stays on DcNoNewDivesView.
      if (hasDives && mounted) {
        ref.read(dcAdapterDownloadCanAdvanceProvider.notifier).state = true;
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// The transport a saved computer's connection type names, or null for
/// one the app cannot reopen directly, such as `cloud`. Every other value
/// used to fall back to BLE, which dialed a cloud computer's stale address
/// over Bluetooth (issue #3106). A missing type still means BLE: records
/// saved before the type was always written carry an address and no type.
DeviceConnectionType? _connectionTypeFromString(String? type) {
  switch (type?.toLowerCase()) {
    case null:
    case 'bluetooth':
    case 'ble':
      return DeviceConnectionType.ble;
    case 'bluetoothclassic':
      return DeviceConnectionType.bluetoothClassic;
    case 'usb':
      return DeviceConnectionType.usb;
    case 'infrared':
      return DeviceConnectionType.infrared;
    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// Searching for a saved computer
// ---------------------------------------------------------------------------

class _KnownDeviceSearchView extends StatelessWidget {
  const _KnownDeviceSearchView({required this.computer});

  final DiveComputer computer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            l10n.diveComputer_download_searchingForDevice(computer.displayName),
          ),
        ],
      ),
    );
  }
}
