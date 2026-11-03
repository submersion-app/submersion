import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/presentation/providers/app_lock_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_settings_provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';

// Fakes and the container builder shared by the auto-connect controller
// tests (issue #3361), split across files to keep each under the size
// limit.

/// Host API stub that records discovery calls without touching a platform
/// channel, mirroring `discovery_scan_for_address_test.dart`.
class FakeHostApi extends pigeon.DiveComputerHostApi {
  int startDiscoveryCalls = 0;
  int stopDiscoveryCalls = 0;

  /// When set, `startDiscovery` throws this, like a switched-off radio.
  Object? startError;

  @override
  Future<void> startDiscovery(pigeon.TransportType transport) async {
    startDiscoveryCalls++;
    final error = startError;
    if (error != null) throw error;
  }

  @override
  Future<void> stopDiscovery() async {
    stopDiscoveryCalls++;
  }
}

/// Records every `startDownload` call instead of running a real transfer.
/// The controller must never call it: an automatic download goes through
/// the computer's download page, which also imports the dives (issue
/// #3361). `markDownloading()`/`finish()` simulate a download running
/// elsewhere, which the controller's guard has to respect.
class FakeDownloadNotifier extends DownloadNotifier {
  FakeDownloadNotifier()
    : super(
        service: pigeon.DiveComputerService(hostApi: FakeHostApi()),
        repository: DiveComputerRepository(),
      );

  final List<({DiscoveredDevice device, DiveComputer? computer})> calls = [];

  @override
  Future<void> startDownload(
    DiscoveredDevice device, {
    DiveComputer? computer,
  }) async {
    calls.add((device: device, computer: computer));
    state = const DownloadState(phase: DownloadPhase.connecting);
  }

  void finish() {
    state = const DownloadState(phase: DownloadPhase.complete);
  }

  /// Simulates a download already running - manual or auto-triggered makes
  /// no difference to `AutoConnectController`'s guard.
  void markDownloading() {
    state = const DownloadState(phase: DownloadPhase.downloading);
  }
}

/// Starts nothing by itself: the test finishes each start, in any order.
class GatedDiscoveryNotifier extends DiscoveryNotifier {
  GatedDiscoveryNotifier(pigeon.DiveComputerService service)
    : super(service: service);

  final List<Completer<void>> starts = [];

  @override
  Future<void> startScan({Object? owner}) {
    final start = Completer<void>();
    starts.add(start);
    return start.future;
  }

  @override
  Future<void> stopScanOwnedBy(Object? owner) async {}
}

/// Lets a test lock and unlock the app, which the real one does from the
/// lifecycle and the unlock form.
class FakeAppLock extends AppLockNotifier {
  // ignore: use_setters_to_change_properties
  void setLocked(bool locked) => state = locked;
}

DiveComputer knownComputer(
  String id, {
  String? bluetoothAddress,
  String? manufacturer,
  String? model,
  String? connectionType,
  bool autoDownloadDisabled = false,
}) => DiveComputer(
  id: id,
  name: 'Computer $id',
  manufacturer: manufacturer,
  model: model,
  connectionType: connectionType,
  bluetoothAddress: bluetoothAddress,
  autoDownloadDisabled: autoDownloadDisabled,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

pigeon.DiscoveredDevice advert(String address, {String name = 'Perdix'}) =>
    pigeon.DiscoveredDevice(
      vendor: 'Shearwater',
      product: 'Perdix',
      model: 10,
      address: address,
      name: name,
      transport: pigeon.TransportType.ble,
    );

/// What [buildAutoConnectHarness] made: the container, the fakes behind
/// it, and the ids of the computers whose download page the controller
/// requested, in order (each new `justTriggered` is one request).
typedef AutoConnectHarness = ({
  ProviderContainer container,
  FakeHostApi hostApi,
  FakeDownloadNotifier downloadNotifier,
  List<String> requested,
});

AutoConnectHarness buildAutoConnectHarness({
  List<DiveComputer> computers = const [],
  bool autoConnectEnabled = true,
  bool failToReadComputers = false,
  Duration modelMatchWindow = Duration.zero,
  DiscoveryNotifier Function(pigeon.DiveComputerService service)? discovery,
}) {
  final hostApi = FakeHostApi();
  final downloadNotifier = FakeDownloadNotifier();
  final service = pigeon.DiveComputerService(hostApi: hostApi);
  final container = ProviderContainer(
    overrides: [
      autoConnectControllerProvider.overrideWith(
        (ref) =>
            AutoConnectController(ref: ref, modelMatchWindow: modelMatchWindow),
      ),
      appLockNotifierProvider.overrideWith(FakeAppLock.new),
      // The real `discoveryNotifierProvider` watches this to build its
      // `DiscoveryNotifier`, so overriding the service - not the
      // notifier - keeps the production wiring intact while swapping in
      // a host API that never touches a platform channel.
      diveComputerServiceProvider.overrideWithValue(service),
      if (discovery != null)
        discoveryNotifierProvider.overrideWith((ref) => discovery(service)),
      downloadNotifierProvider.overrideWith((ref) => downloadNotifier),
      allDiveComputersProvider.overrideWith((ref) async {
        if (failToReadComputers) throw StateError('database unavailable');
        return computers;
      }),
      autoConnectKnownComputersProvider.overrideWith(
        (ref) => AutoConnectKnownComputersNotifier.unstored(autoConnectEnabled),
      ),
    ],
  );
  addTearDown(container.dispose);
  final requested = <String>[];
  // Keeps the autoDispose controller alive for the life of the test, and
  // records each download-page request the way the widget consumes it.
  container.listen(autoConnectControllerProvider, (previous, next) {
    final computer = next.justTriggered;
    if (computer != null && !identical(computer, previous?.justTriggered)) {
      requested.add(computer.id);
    }
  });
  return (
    container: container,
    hostApi: hostApi,
    downloadNotifier: downloadNotifier,
    requested: requested,
  );
}
