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
  /// True while this controller owns an active passive scan.
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
/// [activate]/[deactivate] are
/// called directly by the hosting widget - not left to Riverpod's own
/// dispose - because they must also react to a route being pushed on top
/// (pause) and popped back (resume), not just widget mount/unmount.
class AutoConnectController extends StateNotifier<AutoConnectState> {
  AutoConnectController({required Ref ref})
    : _ref = ref,
      super(const AutoConnectState());

  final Ref _ref;

  /// Whether this controller is the one that started the current scan, so
  /// [deactivate] never stops a scan the manual discovery wizard started on
  /// its own.
  bool _scanOwnedByUs = false;

  ProviderSubscription<List<DiscoveredDevice>>? _devicesSubscription;
  ProviderSubscription<bool>? _downloadingSubscription;
  ProviderSubscription<bool>? _overlaySubscription;
  ProviderSubscription<bool>? _switchSubscription;

  /// Starts the passive scan, if the global switch is on. Safe to call
  /// repeatedly (resuming after a pause is a second `activate()` call).
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

    if (_ref.read(rootOverlayActiveProvider)) return;
    _resume();
  }

  /// Pauses the passive scan while a page covers the section, and tears down
  /// the one-shot listeners. Leaves the root-overlay and switch
  /// subscriptions in place, matching `activate()` being idempotent; the
  /// hosting widget's `dispose()` uses [release] instead.
  void deactivate() {
    _pause();
  }

  /// For the hosting widget's `dispose()`: closes every listener and stops
  /// this controller's own scan, but never sets [state]. `dispose()` runs
  /// while the tree is being torn down, where Riverpod rejects a provider
  /// change, and the controller itself is discarded right after
  /// (`autoDispose`), so its state no longer matters.
  void release() {
    _devicesSubscription?.close();
    _devicesSubscription = null;
    _downloadingSubscription?.close();
    _downloadingSubscription = null;
    _overlaySubscription?.close();
    _overlaySubscription = null;
    _switchSubscription?.close();
    _switchSubscription = null;
    _stopOwnedScan();
  }

  void _resume() {
    if (state.isActive) return;
    if (!_ref.read(autoConnectKnownComputersProvider)) return;

    _scanOwnedByUs = true;
    unawaited(_ref.read(discoveryNotifierProvider.notifier).startScan());

    _devicesSubscription = _ref.listen(discoveredDevicesProvider, (_, _) {
      unawaited(_tryTriggerNextMatch());
    });
    _downloadingSubscription = _ref.listen(isDownloadingProvider, (
      wasDownloading,
      isDownloading,
    ) {
      if (wasDownloading == true && isDownloading == false) {
        unawaited(_tryTriggerNextMatch());
      }
    });

    state = state.copyWith(isActive: true);
    unawaited(_tryTriggerNextMatch());
  }

  void _pause() {
    _devicesSubscription?.close();
    _devicesSubscription = null;
    _downloadingSubscription?.close();
    _downloadingSubscription = null;

    _stopOwnedScan();

    state = state.copyWith(isActive: false);
  }

  void _stopOwnedScan() {
    if (!_scanOwnedByUs) return;
    unawaited(_ref.read(discoveryNotifierProvider.notifier).stopScan());
    _scanOwnedByUs = false;
  }

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
  Future<void> _tryTriggerNextMatch() async {
    if (!_canTrigger) return;

    final List<DiveComputer> computers;
    try {
      // Already scoped to the active diver's own computers
      // (`getAllComputers(diverId: ...)`): a computer belonging to another
      // diver on a shared device never appears here.
      computers = await _ref.read(allDiveComputersProvider.future);
    } catch (error, stackTrace) {
      _log.error(
        'Auto-connect failed to read known computers',
        category: LogCategory.bluetooth,
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    // Checked again: the await yields, so a pause, a download started
    // elsewhere, or another pass that already requested a page can have
    // happened in between.
    if (!mounted || !_canTrigger) return;

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

  bool get _canTrigger => state.isActive && !_ref.read(isDownloadingProvider);

  /// The eligible computer whose device appears earliest in [discovered],
  /// which `DiscoveryNotifier` keeps in the order the devices were found.
  DiveComputer? _firstMatchInDiscoveryOrder(
    List<DiveComputer> computers,
    List<DiscoveredDevice> discovered,
  ) {
    DiveComputer? first;
    var firstIndex = discovered.length;
    for (final computer in computers) {
      if (state.triggeredComputerIds.contains(computer.id)) continue;
      if (computer.autoDownloadDisabled) continue;

      final device = _resolveDevice(computer, discovered);
      if (device == null) continue;

      final index = discovered.indexWhere((d) => identical(d, device));
      if (index >= 0 && index < firstIndex) {
        first = computer;
        firstIndex = index;
      }
    }
    return first;
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
/// if the hosting widget somehow failed to call `deactivate()`.
final autoConnectControllerProvider =
    StateNotifierProvider.autoDispose<AutoConnectController, AutoConnectState>(
      (ref) => AutoConnectController(ref: ref),
    );
