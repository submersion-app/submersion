import 'dart:async';

import 'package:fake_async/fake_async.dart';
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

/// Host API stub that records discovery calls without touching a platform
/// channel, mirroring `discovery_scan_for_address_test.dart`.
class _FakeHostApi extends pigeon.DiveComputerHostApi {
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

/// Starts nothing by itself: the test finishes each start, in any order.
class _GatedDiscoveryNotifier extends DiscoveryNotifier {
  _GatedDiscoveryNotifier(pigeon.DiveComputerService service)
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
class _FakeAppLock extends AppLockNotifier {
  // ignore: use_setters_to_change_properties
  void setLocked(bool locked) => state = locked;
}

DiveComputer _computer(
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

pigeon.DiscoveredDevice _advert(String address, {String name = 'Perdix'}) =>
    pigeon.DiscoveredDevice(
      vendor: 'Shearwater',
      product: 'Perdix',
      model: 10,
      address: address,
      name: name,
      transport: pigeon.TransportType.ble,
    );

void main() {
  late _FakeHostApi hostApi;
  late _FakeDownloadNotifier downloadNotifier;

  /// Ids of the computers whose download page the controller requested, in
  /// order: each new `justTriggered` is one request.
  late List<String> requested;

  ProviderContainer makeContainer({
    List<DiveComputer> computers = const [],
    bool autoConnectEnabled = true,
    bool failToReadComputers = false,
    Duration modelMatchWindow = Duration.zero,
    DiscoveryNotifier Function(pigeon.DiveComputerService service)? discovery,
  }) {
    hostApi = _FakeHostApi();
    downloadNotifier = _FakeDownloadNotifier();
    final service = pigeon.DiveComputerService(hostApi: hostApi);
    final container = ProviderContainer(
      overrides: [
        autoConnectControllerProvider.overrideWith(
          (ref) => AutoConnectController(
            ref: ref,
            modelMatchWindow: modelMatchWindow,
          ),
        ),
        appLockNotifierProvider.overrideWith(_FakeAppLock.new),
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
          (ref) =>
              AutoConnectKnownComputersNotifier.unstored(autoConnectEnabled),
        ),
      ],
    );
    addTearDown(container.dispose);
    requested = [];
    // Keeps the autoDispose controller alive for the life of the test, and
    // records each download-page request the way the widget consumes it.
    container.listen(autoConnectControllerProvider, (previous, next) {
      final computer = next.justTriggered;
      if (computer != null && !identical(computer, previous?.justTriggered)) {
        requested.add(computer.id);
      }
    });
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
      'requests its download page once and pauses the scan', () async {
    final container = makeContainer(
      computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);

    controller.activate();
    await pumpEventQueue();
    expect(hostApi.startDiscoveryCalls, 1);

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(_advert('11:22:33:44:55:66'));
    await pumpEventQueue();

    expect(requested, ['c1']);
    // The page downloads and imports; the controller never downloads
    // directly, or the dives would never reach the logbook.
    expect(downloadNotifier.calls, isEmpty);
    // Paused before the page opens, so its scan cannot fight the page's own.
    expect(hostApi.stopDiscoveryCalls, 1);
    expect(container.read(autoConnectControllerProvider).isActive, isFalse);
  });

  test('the same computer advertising twice in one visit is requested '
      'only once', () async {
    final container = makeContainer(
      computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(_advert('11:22:33:44:55:66'));
    await pumpEventQueue();
    service.onDeviceDiscovered(_advert('11:22:33:44:55:66'));
    await pumpEventQueue();

    expect(requested, ['c1']);
  });

  test('a scan that fails to start stops showing as searching, and the '
      'next activate() tries again', () async {
    final container = makeContainer(
      computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    hostApi.startError = StateError('radio off');

    controller.activate();
    await pumpEventQueue();

    expect(hostApi.startDiscoveryCalls, 1);
    expect(container.read(autoConnectControllerProvider).isActive, isFalse);

    hostApi.startError = null;
    controller.activate();
    await pumpEventQueue();

    expect(hostApi.startDiscoveryCalls, 2);
    expect(container.read(autoConnectControllerProvider).isActive, isTrue);
  });

  test('a scan the native side ends stops showing as searching', () async {
    final container = makeContainer(
      computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();
    expect(container.read(autoConnectControllerProvider).isActive, isTrue);

    container.read(diveComputerServiceProvider).onDiscoveryComplete();
    await pumpEventQueue();

    expect(container.read(autoConnectControllerProvider).isActive, isFalse);
    expect(requested, isEmpty);
  });

  test('a known computer found just before the scan ends is still '
      'requested', () async {
    final container = makeContainer(
      computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(_advert('11:22:33:44:55:66'));
    service.onDiscoveryComplete();
    await pumpEventQueue();

    expect(requested, ['c1']);
  });

  test('known computers that cannot be read: no scan, nothing '
      'requested', () async {
    final container = makeContainer(failToReadComputers: true);
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    expect(hostApi.startDiscoveryCalls, 0);
    expect(requested, isEmpty);
    expect(container.read(autoConnectControllerProvider).isActive, isFalse);
  });

  test('no computer that can be auto-downloaded: no scan, so no Bluetooth '
      'permission prompt either', () async {
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

    expect(hostApi.startDiscoveryCalls, 0);
    expect(container.read(autoConnectControllerProvider).isActive, isFalse);
  });

  test('autoDownloadDisabled: skipped even with the switch on', () async {
    final container = makeContainer(
      computers: [
        _computer(
          'c1',
          bluetoothAddress: '11:22:33:44:55:66',
          autoDownloadDisabled: true,
        ),
        // Keeps the scan running, so the opted-out computer is seen.
        _computer('c2', bluetoothAddress: '99:99:99:99:99:99'),
      ],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(_advert('11:22:33:44:55:66'));
    await pumpEventQueue();

    expect(requested, isEmpty);
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
    service.onDeviceDiscovered(_advert('11:22:33:44:55:66'));
    await pumpEventQueue();

    expect(requested, isEmpty);
  });

  test('a download finishing elsewhere re-runs matching without a new scan '
      'event', () async {
    final container = makeContainer(
      computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    downloadNotifier.markDownloading();
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(_advert('11:22:33:44:55:66'));
    await pumpEventQueue();
    expect(requested, isEmpty);

    downloadNotifier.finish();
    await pumpEventQueue();

    expect(requested, ['c1']);
  });

  test('release() stops its own scan without notifying listeners, so it is '
      "safe from the hosting widget's dispose", () async {
    final container = makeContainer(
      computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();
    expect(hostApi.startDiscoveryCalls, 1);

    var notifications = 0;
    container.listen(autoConnectControllerProvider, (_, _) => notifications++);

    controller.release();
    await pumpEventQueue();

    expect(hostApi.stopDiscoveryCalls, 1);
    expect(notifications, 0);

    // Nothing left listening: the switch flipping afterwards must not
    // restart the scan.
    final enabled = container.read(autoConnectKnownComputersProvider.notifier);
    await enabled.setEnabled(false);
    await enabled.setEnabled(true);
    await pumpEventQueue();
    expect(hostApi.startDiscoveryCalls, 1);
  });

  test(
    'release() does not stop a scan this controller never started',
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
      controller.release();
      await pumpEventQueue();

      expect(hostApi.stopDiscoveryCalls, 0);
    },
  );

  test('returning from the download page does not request the same '
      'computer again; a new visit does', () async {
    final container = makeContainer(
      computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(_advert('11:22:33:44:55:66'));
    await pumpEventQueue();
    expect(requested, ['c1']);

    // The download page covers the section, then is closed again.
    controller.release();
    controller.activate();
    await pumpEventQueue();
    expect(hostApi.startDiscoveryCalls, 2);
    service.onDeviceDiscovered(_advert('11:22:33:44:55:66'));
    await pumpEventQueue();
    expect(requested, ['c1']);

    // Leaving the section disposes the controller; the next visit re-arms.
    container.invalidate(autoConnectControllerProvider);
    container.read(autoConnectControllerProvider.notifier).activate();
    await pumpEventQueue();
    service.onDeviceDiscovered(_advert('11:22:33:44:55:66'));
    await pumpEventQueue();

    expect(requested, ['c1', 'c1']);
  });

  test('two known computers reachable: requested one at a time, in the '
      'order they were discovered', () async {
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
    // B is found first although A comes first in the computer list, and
    // both arrive before the controller's first match pass completes.
    service.onDeviceDiscovered(_advert('22:22:22:22:22:22', name: 'B'));
    service.onDeviceDiscovered(_advert('11:11:11:11:11:11', name: 'A'));
    await pumpEventQueue();

    expect(requested, ['b']);

    // B's download page is closed again; A is still in range.
    controller.release();
    controller.activate();
    await pumpEventQueue();
    service.onDeviceDiscovered(_advert('11:11:11:11:11:11', name: 'A'));
    service.onDeviceDiscovered(_advert('22:22:22:22:22:22', name: 'B'));
    await pumpEventQueue();

    expect(requested, ['b', 'a']);
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
    service.onDeviceDiscovered(_advert('11:22:33:44:55:66'));
    await pumpEventQueue();

    expect(requested, isEmpty);
  });

  test(
    'flipping the switch off while scanning stops the scan right away',
    () async {
      final container = makeContainer(
        computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
      );
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
    final container = makeContainer(
      computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
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

  test('a start that finishes after a newer one began says nothing about '
      'the newer scan', () async {
    late _GatedDiscoveryNotifier discovery;
    final container = makeContainer(
      computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
      discovery: (service) => discovery = _GatedDiscoveryNotifier(service),
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    controller.release();
    controller.activate();
    await pumpEventQueue();
    expect(discovery.starts, hasLength(2));

    // The first start ends, say on a refused prompt, with the second still
    // waiting on its own.
    discovery.starts.first.complete();
    await pumpEventQueue();

    expect(container.read(autoConnectControllerProvider).isActive, isTrue);
  });

  group('while the app is locked', () {
    test('pauses the scan, and resumes on unlock', () async {
      final container = makeContainer(
        computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
      );
      final controller = container.read(autoConnectControllerProvider.notifier);
      final lock =
          container.read(appLockNotifierProvider.notifier) as _FakeAppLock;
      controller.activate();
      await pumpEventQueue();
      expect(hostApi.startDiscoveryCalls, 1);

      lock.setLocked(true);
      await pumpEventQueue();
      expect(hostApi.stopDiscoveryCalls, 1);
      expect(container.read(autoConnectControllerProvider).isActive, isFalse);

      lock.setLocked(false);
      await pumpEventQueue();
      expect(hostApi.startDiscoveryCalls, 2);
      expect(container.read(autoConnectControllerProvider).isActive, isTrue);
    });

    test('coming back to a locked section starts no scan', () async {
      final container = makeContainer(
        computers: [_computer('c1', bluetoothAddress: '11:22:33:44:55:66')],
      );
      final controller = container.read(autoConnectControllerProvider.notifier);
      (container.read(appLockNotifierProvider.notifier) as _FakeAppLock)
          .setLocked(true);

      controller.activate();
      await pumpEventQueue();

      expect(hostApi.startDiscoveryCalls, 0);
    });
  });

  group('computers a scan cannot find start none (no Bluetooth prompt)', () {
    Future<int> startsFor(DiveComputer computer) async {
      final container = makeContainer(computers: [computer]);
      container.read(autoConnectControllerProvider.notifier).activate();
      await pumpEventQueue();
      return hostApi.startDiscoveryCalls;
    }

    test('a USB computer', () async {
      expect(
        await startsFor(
          _computer('c1', connectionType: 'usb', bluetoothAddress: 'COM3'),
        ),
        0,
      );
    });

    test('a Bluetooth Classic computer', () async {
      expect(
        await startsFor(
          _computer(
            'c1',
            connectionType: 'bluetoothClassic',
            bluetoothAddress: 'AA:BB',
          ),
        ),
        0,
      );
    });

    test('a file-imported record, with a model but no transport', () async {
      expect(
        await startsFor(
          _computer('c1', manufacturer: 'Shearwater', model: 'Perdix'),
        ),
        0,
      );
    });

    test('a Garmin saved on another device', () async {
      expect(
        await startsFor(
          _computer(
            'c1',
            manufacturer: 'Garmin',
            model: 'Descent Mk3',
            connectionType: 'bluetooth',
          ),
        ),
        0,
      );
    });

    test('whereas a computer saved on another device, with no address here, '
        'is searched for by model', () async {
      expect(
        await startsFor(
          _computer(
            'c1',
            manufacturer: 'Shearwater',
            model: 'Perdix',
            connectionType: 'bluetooth',
          ),
        ),
        1,
      );
    });
  });

  group('matching by make and model', () {
    DiveComputer perdix(String id, String address, {bool optedOut = false}) =>
        _computer(
          id,
          bluetoothAddress: address,
          manufacturer: 'Shearwater',
          model: 'Perdix',
          connectionType: 'bluetooth',
          autoDownloadDisabled: optedOut,
        );

    test('a computer whose address rotated is found once the window has '
        'passed, not on the first sighting', () {
      fakeAsync((async) {
        final container = makeContainer(
          computers: [perdix('c1', 'OLD')],
          modelMatchWindow: const Duration(seconds: 15),
        );
        container.read(autoConnectControllerProvider.notifier).activate();
        async.flushMicrotasks();

        container
            .read(diveComputerServiceProvider)
            .onDeviceDiscovered(_advert('NEW'));
        async.elapse(const Duration(seconds: 14));
        expect(requested, isEmpty);

        async.elapse(const Duration(seconds: 1));
        expect(requested, ['c1']);
      });
    });

    test('a window cut short matches nothing by model', () {
      fakeAsync((async) {
        final container = makeContainer(
          computers: [perdix('c1', 'OLD')],
          modelMatchWindow: const Duration(seconds: 15),
        );
        container.read(autoConnectControllerProvider.notifier).activate();
        async.flushMicrotasks();

        final service = container.read(diveComputerServiceProvider);
        service.onDeviceDiscovered(_advert('NEW'));
        async.elapse(const Duration(seconds: 1));
        service.onDiscoveryComplete();
        async.elapse(const Duration(seconds: 20));

        expect(requested, isEmpty);
      });
    });

    test('the exact address wins whichever computer comes first', () async {
      final container = makeContainer(
        computers: [perdix('other', 'BB'), perdix('mine', 'AA')],
      );
      container.read(autoConnectControllerProvider.notifier).activate();
      await pumpEventQueue();

      container
          .read(diveComputerServiceProvider)
          .onDeviceDiscovered(_advert('AA'));
      await pumpEventQueue();

      expect(requested, ['mine']);
    });

    test('a device accounted for by its address does not count against the '
        'one device left of that model', () async {
      final container = makeContainer(
        computers: [
          perdix('rotated', 'OLD'),
          perdix('out', 'AA', optedOut: true),
        ],
      );
      container.read(autoConnectControllerProvider.notifier).activate();
      await pumpEventQueue();

      final service = container.read(diveComputerServiceProvider);
      service.onDeviceDiscovered(_advert('AA'));
      service.onDeviceDiscovered(_advert('NEW'));
      await pumpEventQueue();

      expect(requested, ['rotated']);
    });

    test("an opted-out computer's device stands in for no other", () async {
      final container = makeContainer(
        computers: [perdix('other', 'BB'), perdix('out', 'AA', optedOut: true)],
      );
      container.read(autoConnectControllerProvider.notifier).activate();
      await pumpEventQueue();

      container
          .read(diveComputerServiceProvider)
          .onDeviceDiscovered(_advert('AA'));
      await pumpEventQueue();

      expect(requested, isEmpty);
    });

    test("a computer already opened: its device stands in for no other when "
        'the diver comes back', () async {
      final container = makeContainer(
        computers: [perdix('other', 'BB'), perdix('mine', 'AA')],
      );
      final controller = container.read(autoConnectControllerProvider.notifier);
      final service = container.read(diveComputerServiceProvider);
      controller.activate();
      await pumpEventQueue();
      service.onDeviceDiscovered(_advert('AA'));
      await pumpEventQueue();
      expect(requested, ['mine']);

      controller.release();
      controller.activate();
      await pumpEventQueue();
      service.onDeviceDiscovered(_advert('AA'));
      await pumpEventQueue();

      expect(requested, ['mine']);
    });
  });
}
