import 'dart:async';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/presentation/providers/app_lock_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/services/known_computer_reacquisition.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_settings_provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';

/// State for [AutoConnectController] (issue #3361).
class AutoConnectState {
  /// Whether the section shows the passive scan as running. A page covering
  /// the section releases the scan without changing this, since nothing of
  /// the section shows then; the next [AutoConnectController.activate]
  /// brings it back in line.
  final bool isActive;

  /// Ids of computers whose download page was opened during this visit, so
  /// the same computer is not opened again when the diver comes back from
  /// it. Kept across pauses; leaving the section disposes the controller
  /// (`autoDispose`), so the next visit re-arms every computer.
  final Set<String> triggeredComputerIds;

  /// The computer whose download page the widget should open now. The
  /// widget opens it, shows the "Downloading from `name`..." feedback and
  /// clears this via [AutoConnectController.clearTriggerFeedback], so it is
  /// not acted on again on an unrelated rebuild.
  final DiveComputer? justTriggered;

  const AutoConnectState({
    this.isActive = false,
    this.triggeredComputerIds = const {},
    this.justTriggered,
  });

  AutoConnectState copyWith({
    bool? isActive,
    Set<String>? triggeredComputerIds,
    DiveComputer? justTriggered,
    bool clearJustTriggered = false,
  }) => AutoConnectState(
    isActive: isActive ?? this.isActive,
    triggeredComputerIds: triggeredComputerIds ?? this.triggeredComputerIds,
    justTriggered: clearJustTriggered
        ? null
        : (justTriggered ?? this.justTriggered),
  );
}

/// Coordinates the passive auto-connect/auto-download scan for known dive
/// computers (issue #3361) while the Transfer tab's Dive Computers section
/// is visible.
///
/// Drives the *existing* [DiscoveryNotifier] for scanning, and hands each
/// match to the computer's existing download page rather than calling
/// [DownloadNotifier] itself: that page is what imports the dives and
/// updates the computer's dive count, fingerprint and connection, so a
/// download started here directly would never reach the logbook.
/// [activate] and [release] are called directly by the hosting widget - not
/// left to Riverpod's own dispose - because they must also react to a route
/// covering the section and to the app leaving the foreground, not just
/// widget mount/unmount.
class AutoConnectController extends StateNotifier<AutoConnectState> {
  AutoConnectController({
    required Ref ref,
    this.modelMatchWindow = defaultModelMatchWindow,
  }) : _ref = ref,
       super(const AutoConnectState());

  /// As long as the download page's own search by make and model.
  static const defaultModelMatchWindow = Duration(seconds: 15);

  /// How long a scan runs before a computer can match by make and model.
  /// Only a scan that ran this long can say that one device of a model is
  /// nearby: on the first sighting, a buddy's computer of the same model
  /// would open this diver's page and use up its one trigger of the visit.
  final Duration modelMatchWindow;

  final Ref _ref;

  /// Whether the passive scan runs. Kept here rather than read from
  /// [state]: [release] runs where provider state must not change, and a
  /// controller released there has to start again on its next [activate].
  bool _active = false;

  /// Which scan start is the current one: a start that finishes after a
  /// newer one began says nothing about the newer scan.
  int _scanRun = 0;

  /// Whether the current scan has run for [modelMatchWindow].
  bool _modelMatchOpen = false;
  Timer? _modelMatchTimer;

  ProviderSubscription<bool>? _scanningSubscription;
  ProviderSubscription<List<DiscoveredDevice>>? _devicesSubscription;
  ProviderSubscription<bool>? _downloadingSubscription;
  ProviderSubscription<bool>? _lockSubscription;
  ProviderSubscription<bool>? _switchSubscription;
  ProviderSubscription<AsyncValue<List<DiveComputer>>>? _computersSubscription;

  /// Starts the passive scan, if the global switch is on and a known
  /// computer can be auto-downloaded. Safe to call repeatedly (coming back
  /// from a covering page is another `activate()` call).
  void activate() {
    // The lock barrier is no route, so the hosting widget's `RouteAware`
    // never sees it, and a page opened behind it would hide any PIN prompt.
    _lockSubscription ??= _ref.listen(appLockNotifierProvider, (_, isLocked) {
      if (isLocked) {
        _pause();
      } else {
        _resume();
      }
    });

    // Flipping the switch off while this screen is open must stop the scan
    // right away, not just leave it running until the section is re-entered.
    _switchSubscription ??= _ref.listen(autoConnectKnownComputersProvider, (
      _,
      isEnabled,
    ) {
      if (isEnabled) {
        _resume();
      } else {
        _pause();
      }
    });

    // No computer to auto-download, no scan: a diver with none is never
    // asked for Bluetooth access here, and the scan starts or stops as
    // computers are added, removed or opted out while the section is open.
    // Deferred like the match, for the same reason (see [_scheduleMatch]).
    _computersSubscription ??= _ref.listen(allDiveComputersProvider, (_, next) {
      scheduleMicrotask(() {
        if (mounted && _computersSubscription != null) {
          _onComputersChanged(next);
        }
      });
    });

    _resume();
    // [release] leaves the shown state as it was; bring it in line now, or
    // "Searching..." would keep spinning without a scan behind it.
    if (!_active && state.isActive) state = state.copyWith(isActive: false);
  }

  /// For a route covering the section, the app leaving the foreground and
  /// the hosting widget's `dispose()`: closes every listener and stops this
  /// controller's own scan, but never sets [state]. A page is pushed from
  /// inside the navigator's rebuild and `dispose()` runs while the tree is
  /// torn down, both places where Riverpod rejects a provider change.
  /// Closing the listeners right away also keeps a match from opening a
  /// download page over the page just pushed; [activate] sets them up again.
  void release() {
    _closeScanListeners();
    _lockSubscription?.close();
    _lockSubscription = null;
    _switchSubscription?.close();
    _switchSubscription = null;
    _computersSubscription?.close();
    _computersSubscription = null;
    _stopOwnScan();
  }

  void _onComputersChanged(AsyncValue<List<DiveComputer>> next) {
    if (next.hasError) {
      _log.error(
        'Auto-connect could not read the known computers',
        category: LogCategory.bluetooth,
        error: next.error,
        stackTrace: next.stackTrace,
      );
      return;
    }
    final computers = next.valueOrNull;
    if (computers == null) return;
    if (!_hasEligibleComputer(computers)) {
      _pause();
    } else if (_active) {
      // A computer added or opted back in may be one whose device the scan
      // already found, which produces no new scan event of its own.
      _tryTriggerNextMatch();
    } else {
      _resume();
    }
  }

  /// Runs the match on a microtask. The listeners that call this can fire
  /// while a widget's build reads one of the providers they watch, and the
  /// match changes this controller's state, which Riverpod rejects there.
  void _scheduleMatch() => scheduleMicrotask(() {
    if (mounted) _tryTriggerNextMatch();
  });

  void _resume() {
    if (_active) return;
    if (_ref.read(appLockNotifierProvider)) return;
    if (!_ref.read(autoConnectKnownComputersProvider)) return;
    final computers = _ref.read(allDiveComputersProvider).valueOrNull;
    if (computers == null || !_hasEligibleComputer(computers)) return;

    _active = true;
    final run = ++_scanRun;
    unawaited(
      _ref.read(discoveryNotifierProvider.notifier).startScan(owner: this).then(
        (_) {
          if (!mounted || !_active || run != _scanRun) return;
          // A refused permission, a switched-off radio or a native start
          // error is caught inside DiscoveryNotifier and leaves it not
          // scanning; without this, "Searching..." would keep spinning
          // and the next resume would be refused.
          if (!_ref.read(discoveryNotifierProvider).isScanning) {
            _onOwnScanEnded();
            return;
          }
          // Counted from here, not from the request: a permission prompt
          // or Android's scan pacing can hold the start back for longer
          // than the window itself.
          _modelMatchTimer = Timer(modelMatchWindow, () {
            _modelMatchOpen = true;
            _scheduleMatch();
          });
        },
      ),
    );

    _scanningSubscription = _ref.listen(
      discoveryNotifierProvider.select((s) => s.isScanning),
      (wasScanning, isScanning) {
        if (wasScanning == true && !isScanning) _onOwnScanEnded();
      },
    );
    _devicesSubscription = _ref.listen(
      discoveredDevicesProvider,
      (_, _) => _scheduleMatch(),
    );
    _downloadingSubscription = _ref.listen(isDownloadingProvider, (
      wasDownloading,
      isDownloading,
    ) {
      if (wasDownloading == true && isDownloading == false) {
        _scheduleMatch();
      }
    });

    state = state.copyWith(isActive: true);
    _scheduleMatch();
  }

  void _pause() {
    _closeScanListeners();
    _stopOwnScan();
    if (state.isActive) state = state.copyWith(isActive: false);
  }

  /// The scan failed to start or ended on its own (the native side reported
  /// discovery complete). Deferred like the match: a device found just
  /// before the end still gets its pass, and the state change cannot land
  /// inside a build. Coming back to the section, the switch or the
  /// computers changing start a new scan.
  void _onOwnScanEnded() => scheduleMicrotask(() {
    if (!mounted || !_active) return;
    _tryTriggerNextMatch();
    if (!_active) return;
    _log.info(
      'Auto-connect scan ended without a match',
      category: LogCategory.bluetooth,
    );
    _pause();
  });

  void _closeScanListeners() {
    _scanningSubscription?.close();
    _scanningSubscription = null;
    _devicesSubscription?.close();
    _devicesSubscription = null;
    _downloadingSubscription?.close();
    _downloadingSubscription = null;
    _modelMatchTimer?.cancel();
    _modelMatchTimer = null;
    _modelMatchOpen = false;
  }

  /// Stops the scan only if this controller started it, so a scan the
  /// wizard or a download page runs keeps running.
  void _stopOwnScan() {
    _active = false;
    logFailure(
      _ref.read(discoveryNotifierProvider.notifier).stopScanOwnedBy(this),
      AutoConnectController,
      'stop the auto-connect scan',
    );
  }

  static bool _isEligible(DiveComputer computer) =>
      !computer.autoDownloadDisabled && canFindByScan(computer);

  static bool _hasEligibleComputer(List<DiveComputer> computers) =>
      computers.any(_isEligible);

  /// Consumed by the widget right after it shows the "Downloading from
  /// `name`..." feedback for [AutoConnectState.justTriggered].
  void clearTriggerFeedback() {
    state = state.copyWith(clearJustTriggered: true);
  }

  /// Matches the discovered devices against the active diver's own known
  /// computers and requests the download page of at most one per pass, the
  /// one found first. Computers in range are handled one at a time: the
  /// page covers the section and pauses this controller, and coming back
  /// resumes the scan, which finds the next one. Re-running on every
  /// `isDownloadingProvider` `true -> false` edge as well covers a download
  /// that was still running elsewhere when a computer was already in range.
  ///
  /// No await between the checks and the request, so a pause or another
  /// pass cannot slip in between them.
  void _tryTriggerNextMatch() {
    if (!_active || _ref.read(isDownloadingProvider)) return;

    // Already scoped to the active diver's own computers
    // (`getAllComputers(diverId: ...)`): a computer belonging to another
    // diver on a shared device never appears here. Loaded before the scan
    // started (see `_resume`).
    final computers = _ref.read(allDiveComputersProvider).valueOrNull;
    if (computers == null) return;

    final computer = _firstMatchInDiscoveryOrder(
      computers,
      _ref.read(discoveredDevicesProvider),
    );
    if (computer == null) return;

    state = state.copyWith(
      triggeredComputerIds: {...state.triggeredComputerIds, computer.id},
      justTriggered: computer,
    );
    // Paused before the page opens: stops this scan so it cannot fight the
    // page's own, and closes the listeners so nothing requests a second page
    // meanwhile.
    _pause();
  }

  /// The computer to open next: the one whose device appears earliest in
  /// [discovered], which `DiscoveryNotifier` keeps in the order the devices
  /// were found.
  ///
  /// Every known computer claims the device at its stored address first,
  /// even one that cannot be opened now: that device is accounted for, and
  /// must not stand in for another computer of the same model. What is left
  /// goes to the manufacturer/model fallback the manual flow uses for a
  /// computer whose address rotated or never synced to this device (issue
  /// #1423, #3710), once [modelMatchWindow] has passed. Unlike the manual
  /// flow, nobody picked the computer here, so a model two of the diver's
  /// computers share matches neither.
  DiveComputer? _firstMatchInDiscoveryOrder(
    List<DiveComputer> computers,
    List<DiscoveredDevice> discovered,
  ) {
    final owners = Map<DiscoveredDevice, DiveComputer>.identity();
    for (final computer in computers) {
      final address = computer.bluetoothAddress;
      if (address == null) continue;
      for (final device in discovered) {
        if (bluetoothAddressesMatch(device.address, address)) {
          owners.putIfAbsent(device, () => computer);
        }
      }
    }

    if (_modelMatchOpen) {
      final unclaimed = [
        for (final device in discovered)
          if (!owners.containsKey(device)) device,
      ];
      for (final computer in computers) {
        if (!_canOpen(computer) || owners.containsValue(computer)) continue;
        // Another scan target of the same model, not found at its own
        // address, could just as well be the device in range.
        final ambiguous = computers.any(
          (other) =>
              !identical(other, computer) &&
              !owners.containsValue(other) &&
              canFindByScan(other) &&
              isSameSavedModel(other, computer),
        );
        if (ambiguous) continue;
        final device = sameModelFallbackDevice(
          computer: computer,
          discovered: unclaimed,
        );
        if (device != null) owners.putIfAbsent(device, () => computer);
      }
    }

    for (final device in discovered) {
      final computer = owners[device];
      if (computer != null && _canOpen(computer)) return computer;
    }
    return null;
  }

  bool _canOpen(DiveComputer computer) =>
      _isEligible(computer) &&
      !state.triggeredComputerIds.contains(computer.id);

  @override
  void dispose() {
    _modelMatchTimer?.cancel();
    super.dispose();
  }

  static final LoggerService _log = LoggerService.forClass(
    AutoConnectController,
  );
}

/// `autoDispose` so the computers opened during a visit are forgotten once
/// nothing shows the section: the next visit re-arms every one of them. The
/// scan itself is stopped by the hosting widget, through `release()`.
final autoConnectControllerProvider =
    StateNotifierProvider.autoDispose<AutoConnectController, AutoConnectState>(
      (ref) => AutoConnectController(ref: ref),
    );
