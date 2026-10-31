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

  /// Ids of computers downloaded-or-downloading during this visit, so a
  /// repeat advertisement from the same device during the same visit is not
  /// retried. Cleared on [AutoConnectController.activate], so leaving and
  /// re-entering the section re-arms every computer.
  final Set<String> triggeredComputerIds;

  /// The computer an auto-trigger just started downloading from, surfaced
  /// once for the "Downloading from `name`..." feedback. The widget clears
  /// it via [AutoConnectController.clearTriggerFeedback] right after
  /// showing it, so it is not re-shown on an unrelated rebuild.
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
/// Drives the *existing* [DiscoveryNotifier] and [DownloadNotifier] rather
/// than reimplementing scanning or downloading. [activate]/[deactivate] are
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

  /// Stops the passive scan and tears down the one-shot listeners. Leaves
  /// the root-overlay and switch subscriptions in place, matching
  /// `activate()` being idempotent: the hosting widget's own `dispose()`
  /// discards this whole controller instance anyway (`autoDispose`).
  void deactivate() {
    _pause();
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

    if (_scanOwnedByUs) {
      unawaited(_ref.read(discoveryNotifierProvider.notifier).stopScan());
      _scanOwnedByUs = false;
    }

    state = state.copyWith(isActive: false, triggeredComputerIds: const {});
  }

  /// Consumed by the widget right after it shows the "Downloading from
  /// `name`..." feedback for [AutoConnectState.justTriggered].
  void clearTriggerFeedback() {
    state = state.copyWith(clearJustTriggered: true);
  }

  /// Matches every discovered device against the active diver's own known
  /// computers and starts at most one download per pass - `DownloadNotifier`
  /// holds a single device/computer pair, not a queue. Re-running this on
  /// every scan result AND on every `isDownloadingProvider` `true -> false`
  /// edge is what delivers "download sequentially from everything in
  /// range": a computer already visible when another one's download starts
  /// never produces a new scan event of its own.
  Future<void> _tryTriggerNextMatch() async {
    if (!state.isActive) return;
    if (_ref.read(isDownloadingProvider)) return;

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
    final discovered = _ref.read(discoveredDevicesProvider);

    for (final computer in computers) {
      if (state.triggeredComputerIds.contains(computer.id)) continue;
      if (computer.autoDownloadDisabled) continue;

      final device = _resolveDevice(computer, discovered);
      if (device == null) continue;

      state = state.copyWith(
        triggeredComputerIds: {...state.triggeredComputerIds, computer.id},
        justTriggered: computer,
      );
      unawaited(
        _ref
            .read(downloadNotifierProvider.notifier)
            .startDownload(device, computer: computer)
            .catchError((Object error, StackTrace stackTrace) {
              _log.error(
                'Auto-connect download failed to start for '
                '${computer.displayName}',
                category: LogCategory.bluetooth,
                error: error,
                stackTrace: stackTrace,
              );
            }),
      );
      return;
    }
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
