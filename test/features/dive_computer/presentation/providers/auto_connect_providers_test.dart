import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/root_overlay_providers.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_settings_provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';

/// Host API stub that records discovery calls without touching a platform
/// channel, mirroring `discovery_scan_for_address_test.dart`.
class _FakeHostApi extends pigeon.DiveComputerHostApi {
  int startDiscoveryCalls = 0;
  int stopDiscoveryCalls = 0;

  @override
  Future<void> startDiscovery(pigeon.TransportType transport) async {
    startDiscoveryCalls++;
  }

  @override
  Future<void> stopDiscovery() async {
    stopDiscoveryCalls++;
  }
}

/// Records every `startDownload` call instead of running a real transfer, so
/// `AutoConnectController`'s trigger logic can be verified without a real
/// `DiveComputerService`/`DiveComputerRepository` behind it. `finish()` lets
/// a test simulate the download completing, which is what re-arms matching
/// for a second known computer still in range (issue #3361).
class _FakeDownloadNotifier extends DownloadNotifier {
  _FakeDownloadNotifier()
    : super(
        service: pigeon.DiveComputerService(hostApi: _FakeHostApi()),
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

DiveComputer _computer(
  String id, {
  String? bluetoothAddress,
  bool autoDownloadDisabled = false,
}) => DiveComputer(
  id: id,
  name: 'Computer $id',
  bluetoothAddress: bluetoothAddress,
  autoDownloadDisabled: autoDownloadDisabled,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  late _FakeHostApi hostApi;
  late _FakeDownloadNotifier downloadNotifier;

  ProviderContainer makeContainer({
    List<DiveComputer> computers = const [],
    bool autoConnectEnabled = true,
  }) {
    hostApi = _FakeHostApi();
    downloadNotifier = _FakeDownloadNotifier();
    final container = ProviderContainer(
      overrides: [
        // The real `discoveryNotifierProvider` watches this to build its
        // `DiscoveryNotifier`, so overriding the service - not the
        // notifier - keeps the production wiring intact while swapping in
        // a host API that never touches a platform channel.
        diveComputerServiceProvider.overrideWithValue(
          pigeon.DiveComputerService(hostApi: hostApi),
        ),
        downloadNotifierProvider.overrideWith((ref) => downloadNotifier),
        allDiveComputersProvider.overrideWith((ref) async => computers),
        autoConnectKnownComputersProvider.overrideWith(
          (ref) =>
              AutoConnectKnownComputersNotifier.unstored(autoConnectEnabled),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Keeps the autoDispose controller alive for the life of the test.
    container.listen(autoConnectControllerProvider, (_, _) {});
    return container;
  }

  test('switch off: activate() does not start a scan', () async {
    final container = makeContainer(
      computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
      autoConnectEnabled: false,
    );
    final controller = container.read(autoConnectControllerProvider.notifier);

    controller.activate();
    await pumpEventQueue();

    expect(hostApi.startDiscoveryCalls, 0);
    expect(container.read(autoConnectControllerProvider).isActive, isFalse);
  });

  test('switch on, known computer discovered, not opted out, idle -> '
      'startDownload called exactly once', () async {
    final container = makeContainer(
      computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);

    controller.activate();
    await pumpEventQueue();
    expect(hostApi.startDiscoveryCalls, 1);

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(
      pigeon.DiscoveredDevice(
        vendor: 'Shearwater',
        product: 'Perdix',
        model: 10,
        address: '11:22:33:44:55:66',
        name: 'Perdix',
        transport: pigeon.TransportType.ble,
      ),
    );
    await pumpEventQueue();

    expect(downloadNotifier.calls, hasLength(1));
    expect(downloadNotifier.calls.single.computer?.id, 'c1');
  });

  test('the same computer advertising twice in one visit triggers '
      'startDownload only once', () async {
    final container = makeContainer(
      computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    final advert = pigeon.DiscoveredDevice(
      vendor: 'Shearwater',
      product: 'Perdix',
      model: 10,
      address: '11:22:33:44:55:66',
      name: 'Perdix',
      transport: pigeon.TransportType.ble,
    );
    service.onDeviceDiscovered(advert);
    await pumpEventQueue();
    // A repeat advertisement of the exact same device from the native
    // side is already deduplicated by DiscoveryNotifier itself
    // (`_onDeviceDiscovered`), so re-emitting it does not even change
    // `discoveredDevicesProvider` - nothing for the controller to
    // re-match against. The id-based `triggeredComputerIds` guard is
    // what covers a second device matching the SAME computer.
    service.onDeviceDiscovered(advert);
    await pumpEventQueue();

    expect(downloadNotifier.calls, hasLength(1));
  });

  test('autoDownloadDisabled: skipped even with the switch on', () async {
    final container = makeContainer(
      computers: [
        _computer(
          'c1',
          bluetoothAddress: '11:22:33:44:55:66',
          autoDownloadDisabled: true,
        ),
      ],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(
      pigeon.DiscoveredDevice(
        vendor: 'Shearwater',
        product: 'Perdix',
        model: 10,
        address: '11:22:33:44:55:66',
        name: 'Perdix',
        transport: pigeon.TransportType.ble,
      ),
    );
    await pumpEventQueue();

    expect(downloadNotifier.calls, isEmpty);
  });

  test('a manual download already in progress suppresses the auto-trigger '
      'for that cycle', () async {
    final container = makeContainer(
      computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    downloadNotifier.markDownloading();
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(
      pigeon.DiscoveredDevice(
        vendor: 'Shearwater',
        product: 'Perdix',
        model: 10,
        address: '11:22:33:44:55:66',
        name: 'Perdix',
        transport: pigeon.TransportType.ble,
      ),
    );
    await pumpEventQueue();

    expect(downloadNotifier.calls, isEmpty);
  });

  test(
    'deactivate() does not stop a scan this controller never started',
    () async {
      final container = makeContainer(
        computers: const [],
        autoConnectEnabled: false,
      );
      // A manual wizard starts its own scan independently of the
      // controller, through the same DiscoveryNotifier instance.
      await container.read(discoveryNotifierProvider.notifier).startScan();
      expect(hostApi.startDiscoveryCalls, 1);

      final controller = container.read(autoConnectControllerProvider.notifier);
      controller.activate(); // no-op: the switch is off
      controller.deactivate();
      await pumpEventQueue();

      expect(hostApi.stopDiscoveryCalls, 0);
    },
  );

  test(
    'leaving and re-entering the section resets triggeredComputerIds',
    () async {
      final container = makeContainer(
        computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
      );
      final controller = container.read(autoConnectControllerProvider.notifier);
      controller.activate();
      await pumpEventQueue();

      final service = container.read(diveComputerServiceProvider);
      final advert = pigeon.DiscoveredDevice(
        vendor: 'Shearwater',
        product: 'Perdix',
        model: 10,
        address: '11:22:33:44:55:66',
        name: 'Perdix',
        transport: pigeon.TransportType.ble,
      );
      service.onDeviceDiscovered(advert);
      await pumpEventQueue();
      expect(downloadNotifier.calls, hasLength(1));

      controller.deactivate();
      downloadNotifier.finish();
      controller.activate();
      await pumpEventQueue();
      service.onDeviceDiscovered(advert);
      await pumpEventQueue();

      expect(downloadNotifier.calls, hasLength(2));
    },
  );

  test('two known computers both reachable: B downloads automatically once '
      "A's download completes, without a new scan event", () async {
    final container = makeContainer(
      computers: [
        _computer('a', bluetoothAddress: '11:11:11:11:11:11'),
        _computer('b', bluetoothAddress: '22:22:22:22:22:22'),
      ],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(
      pigeon.DiscoveredDevice(
        vendor: 'Shearwater',
        product: 'Perdix',
        model: 10,
        address: '11:11:11:11:11:11',
        name: 'A',
        transport: pigeon.TransportType.ble,
      ),
    );
    service.onDeviceDiscovered(
      pigeon.DiscoveredDevice(
        vendor: 'Shearwater',
        product: 'Perdix',
        model: 10,
        address: '22:22:22:22:22:22',
        name: 'B',
        transport: pigeon.TransportType.ble,
      ),
    );
    await pumpEventQueue();

    // Both devices were already visible when A was picked; only A
    // started, since DownloadNotifier cannot run two at once.
    expect(downloadNotifier.calls, hasLength(1));
    expect(downloadNotifier.calls.single.computer?.id, 'a');

    downloadNotifier.finish();
    await pumpEventQueue();

    expect(downloadNotifier.calls, hasLength(2));
    expect(downloadNotifier.calls.last.computer?.id, 'b');
  });

  test('a computer absent from allDiveComputersProvider (e.g. belonging to a '
      'different diver) is never matched', () async {
    // allDiveComputersProvider already scopes to the active diver
    // (getAllComputers(diverId: ...)); the controller trusts whatever
    // list it is given rather than re-checking diverId itself.
    final container = makeContainer(computers: const []);
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(
      pigeon.DiscoveredDevice(
        vendor: 'Shearwater',
        product: 'Perdix',
        model: 10,
        address: '11:22:33:44:55:66',
        name: 'Perdix',
        transport: pigeon.TransportType.ble,
      ),
    );
    await pumpEventQueue();

    expect(downloadNotifier.calls, isEmpty);
  });

  test(
    'flipping the switch off while scanning stops the scan right away',
    () async {
      final container = makeContainer(computers: const []);
      final controller = container.read(autoConnectControllerProvider.notifier);
      controller.activate();
      await pumpEventQueue();
      expect(hostApi.startDiscoveryCalls, 1);

      await container
          .read(autoConnectKnownComputersProvider.notifier)
          .setEnabled(false);
      await pumpEventQueue();

      expect(hostApi.stopDiscoveryCalls, 1);
      expect(container.read(autoConnectControllerProvider).isActive, isFalse);
    },
  );

  test('flipping the switch back on while visible resumes the scan', () async {
    final container = makeContainer(computers: const []);
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    await container
        .read(autoConnectKnownComputersProvider.notifier)
        .setEnabled(false);
    await pumpEventQueue();
    await container
        .read(autoConnectKnownComputersProvider.notifier)
        .setEnabled(true);
    await pumpEventQueue();

    expect(hostApi.startDiscoveryCalls, 2);
    expect(container.read(autoConnectControllerProvider).isActive, isTrue);
  });

  group('root-navigator overlay guard (issue #3361, Task 4b)', () {
    test('pauses the scan while a root overlay is active', () async {
      final container = makeContainer(computers: const []);
      final controller = container.read(autoConnectControllerProvider.notifier);
      controller.activate();
      await pumpEventQueue();
      expect(hostApi.startDiscoveryCalls, 1);

      container.read(rootOverlayActiveProvider.notifier).state = true;
      await pumpEventQueue();

      expect(hostApi.stopDiscoveryCalls, 1);
      expect(container.read(autoConnectControllerProvider).isActive, isFalse);
    });

    test('resumes once the root overlay clears', () async {
      final container = makeContainer(computers: const []);
      final controller = container.read(autoConnectControllerProvider.notifier);
      controller.activate();
      await pumpEventQueue();

      container.read(rootOverlayActiveProvider.notifier).state = true;
      await pumpEventQueue();
      container.read(rootOverlayActiveProvider.notifier).state = false;
      await pumpEventQueue();

      expect(hostApi.startDiscoveryCalls, 2);
      expect(container.read(autoConnectControllerProvider).isActive, isTrue);
    });
  });
}
