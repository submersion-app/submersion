import 'dart:async';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/root_overlay_providers.dart';
import 'package:submersion/core/services/logger_service.dart';
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
/// being pushed on top and popped back, not just widget mount/unmount.
class AutoConnectController extends StateNotifier<AutoConnectState> {
  AutoConnectController({required Ref ref})
    : _ref = ref,
      super(const AutoConnectState());

  final Ref _ref;

  /// Whether the passive scan runs. Kept here rather than read from
  /// [state]: [release] runs where provider state must not change, and a
  /// controller released there has to start again on its next [activate].
  bool _active = false;

  ProviderSubscription<List<DiscoveredDevice>>? _devicesSubscription;
  ProviderSubscription<bool>? _downloadingSubscription;
  ProviderSubscription<bool>? _overlaySubscription;
  ProviderSubscription<bool>? _switchSubscription;
  ProviderSubscription<AsyncValue<List<DiveComputer>>>? _computersSubscription;

  /// Starts the passive scan, if the global switch is on and a known
  /// computer can be auto-downloaded. Safe to call repeatedly (coming back
  /// from a covering page is another `activate()` call).
  void activate() {
    _overlaySubscription ??= _ref.listen(rootOverlayActiveProvider, (
      _,
      isOverlayActive,
    ) {
      if (isOverlayActive) {
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
      if (!isEnabled) {
        _pause();
      } else if (!_ref.read(rootOverlayActiveProvider)) {
        _resume();
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

    if (!_ref.read(rootOverlayActiveProvider)) _resume();
    // [release] leaves the shown state as it was; bring it in line now, or
    // "Searching..." would keep spinning without a scan behind it.
    if (!_active && state.isActive) state = state.copyWith(isActive: false);
  }

  /// For a page covering the section and for the hosting widget's
  /// `dispose()`: closes every listener and stops this controller's own
  /// scan, but never sets [state]. A page is pushed from inside the
  /// navigator's rebuild and `dispose()` runs while the tree is torn down,
  /// both places where Riverpod rejects a provider change. Closing the
  /// listeners right away also keeps a match from opening a download page
  /// over the page just pushed; [activate] sets them up again.
  void release() {
    _closeScanListeners();
    _overlaySubscription?.close();
    _overlaySubscription = null;
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
    } else if (!_ref.read(rootOverlayActiveProvider)) {
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
    if (!_ref.read(autoConnectKnownComputersProvider)) return;
    final computers = _ref.read(allDiveComputersProvider).valueOrNull;
    if (computers == null || !_hasEligibleComputer(computers)) return;

    _active = true;
    unawaited(
      _ref.read(discoveryNotifierProvider.notifier).startScan(owner: this),
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

  void _closeScanListeners() {
    _devicesSubscription?.close();
    _devicesSubscription = null;
    _downloadingSubscription?.close();
    _downloadingSubscription = null;
  }

  /// Stops the scan only if this controller started it, so a scan the
  /// wizard or a download page runs keeps running.
  void _stopOwnScan() {
    _active = false;
    unawaited(
      _ref.read(discoveryNotifierProvider.notifier).stopScanOwnedBy(this),
    );
  }

  static bool _hasEligibleComputer(List<DiveComputer> computers) =>
      computers.any((computer) => !computer.autoDownloadDisabled);

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

  /// The eligible computer whose device appears earliest in [discovered],
  /// which `DiscoveryNotifier` keeps in the order the devices were found.
  DiveComputer? _firstMatchInDiscoveryOrder(
    List<DiveComputer> computers,
    List<DiscoveredDevice> discovered,
  ) {
    final byDevice = Map<DiscoveredDevice, DiveComputer>.identity();
    for (final computer in computers) {
      if (state.triggeredComputerIds.contains(computer.id)) continue;
      if (computer.autoDownloadDisabled) continue;
      final device = _resolveDevice(computer, discovered);
      if (device != null) byDevice.putIfAbsent(device, () => computer);
    }
    for (final device in discovered) {
      final computer = byDevice[device];
      if (computer != null) return computer;
    }
    return null;
  }

  /// Resolves the discovered device for [computer]: an exact Bluetooth
  /// address match first, then the same manufacturer/model fallback the
  /// manual flow uses for a computer whose address rotated or never synced
  /// to this device (issue #1423, #3710).
  DiscoveredDevice? _resolveDevice(
    DiveComputer computer,
    List<DiscoveredDevice> discovered,
  ) {
    final address = computer.bluetoothAddress;
    if (address != null) {
      for (final device in discovered) {
        if (bluetoothAddressesMatch(device.address, address)) return device;
      }
    }
    return sameModelFallbackDevice(computer: computer, discovered: discovered);
  }

  static final LoggerService _log = LoggerService.forClass(
    AutoConnectController,
  );
}

/// `autoDispose` so leaving the Transfer tab entirely tears this down even
/// if the hosting widget somehow failed to call `release()`.
final autoConnectControllerProvider =
    StateNotifierProvider.autoDispose<AutoConnectController, AutoConnectState>(
      (ref) => AutoConnectController(ref: ref),
    );
