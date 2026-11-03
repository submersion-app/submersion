import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/presentation/providers/app_lock_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

import 'auto_connect_test_support.dart';

/// A real discovery notifier whose scans start only once [_gate] completes,
/// like a start Android's scan pacing holds back.
class _DelayedStartDiscovery extends DiscoveryNotifier {
  _DelayedStartDiscovery(pigeon.DiveComputerService service, this._gate)
    : super(service: service, requiresRuntimePermissions: false);

  final Future<void> _gate;

  @override
  Future<void> startScan({Object? owner}) async {
    await _gate;
    return super.startScan(owner: owner);
  }
}

/// Auto-connect controller (issue #3361): the app lock, computers a scan
/// cannot find, and matching by make and model. The rest of the
/// controller's tests are in auto_connect_providers_test.dart.
void main() {
  late FakeHostApi hostApi;
  late List<String> requested;

  ProviderContainer makeContainer({
    List<DiveComputer> computers = const [],
    bool autoConnectEnabled = true,
    bool failToReadComputers = false,
    Duration modelMatchWindow = Duration.zero,
    DiscoveryNotifier Function(pigeon.DiveComputerService service)? discovery,
    Map<String, List<DiveComputerConnection>> connections = const {},
  }) {
    final harness = buildAutoConnectHarness(
      computers: computers,
      autoConnectEnabled: autoConnectEnabled,
      failToReadComputers: failToReadComputers,
      modelMatchWindow: modelMatchWindow,
      discovery: discovery,
      connections: connections,
    );
    hostApi = harness.hostApi;
    requested = harness.requested;
    return harness.container;
  }

  group('while the app is locked', () {
    test('pauses the scan, and resumes on unlock', () async {
      final container = makeContainer(
        computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
      );
      final controller = container.read(autoConnectControllerProvider.notifier);
      final lock =
          container.read(appLockNotifierProvider.notifier) as FakeAppLock;
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
        computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
      );
      final controller = container.read(autoConnectControllerProvider.notifier);
      (container.read(appLockNotifierProvider.notifier) as FakeAppLock)
          .setLocked(true);

      controller.activate();
      await pumpEventQueue();

      expect(hostApi.startDiscoveryCalls, 0);
    });
  });

  // Issue #3106: a computer's transport and address on this device live in
  // its connections, and the download page this hands a match to reads
  // them there. The legacy type says 'bluetooth' for BLE and Classic alike.
  group('computers as their download page sees them', () {
    DiveComputerConnection connection(
      String computerId,
      DiveComputerConnectionKind kind,
      String address,
    ) => DiveComputerConnection(
      id: '$computerId-${kind.name}',
      computerId: computerId,
      kind: kind,
      address: address,
      firstUsedAt: DateTime(2026, 1, 1),
      lastUsedAt: DateTime(2026, 1, 1),
      localLastUsedAt: DateTime(2026, 1, 1),
    );

    test('a computer reached here over Bluetooth Classic starts no scan, '
        'whatever its legacy type says', () async {
      final container = makeContainer(
        computers: [
          knownComputer(
            'classic',
            connectionType: 'bluetooth',
            bluetoothAddress: 'AA',
            manufacturer: 'Heinrichs Weikamp',
            model: 'OSTC 3',
          ),
        ],
        connections: {
          'classic': [
            connection(
              'classic',
              DiveComputerConnectionKind.bluetoothClassic,
              'AA',
            ),
          ],
        },
      );
      container.read(autoConnectControllerProvider.notifier).activate();
      await pumpEventQueue();

      expect(hostApi.startDiscoveryCalls, 0);
    });

    test('a computer is matched at the address its connection holds here, '
        'at once', () {
      fakeAsync((async) {
        final container = makeContainer(
          computers: [
            knownComputer(
              'c1',
              connectionType: 'bluetooth',
              manufacturer: 'Shearwater',
              model: 'Perdix',
            ),
          ],
          connections: {
            'c1': [connection('c1', DiveComputerConnectionKind.ble, 'AA')],
          },
          modelMatchWindow: const Duration(seconds: 15),
        );
        // elapse(zero) runs what is due now, without moving the clock
        // toward the make-and-model window.
        container.read(autoConnectControllerProvider.notifier).activate();
        async.elapse(Duration.zero);

        container
            .read(diveComputerServiceProvider)
            .onDeviceDiscovered(advert('AA'));
        async.elapse(Duration.zero);

        expect(requested, ['c1']);
      });
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
          knownComputer('c1', connectionType: 'usb', bluetoothAddress: 'COM3'),
        ),
        0,
      );
    });

    test('a Bluetooth Classic computer', () async {
      expect(
        await startsFor(
          knownComputer(
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
          knownComputer('c1', manufacturer: 'Shearwater', model: 'Perdix'),
        ),
        0,
      );
    });

    test('a Garmin saved on another device', () async {
      expect(
        await startsFor(
          knownComputer(
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
          knownComputer(
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
        knownComputer(
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
            .onDeviceDiscovered(advert('NEW'));
        async.elapse(const Duration(seconds: 14));
        expect(requested, isEmpty);

        async.elapse(const Duration(seconds: 1));
        expect(requested, ['c1']);
      });
    });

    test('the window counts from the scan starting, not from the request', () {
      fakeAsync((async) {
        // Android can hold a start back up to 30 seconds (scan pacing).
        final gate = Completer<void>();
        final container = makeContainer(
          computers: [perdix('c1', 'OLD')],
          modelMatchWindow: const Duration(seconds: 15),
          discovery: (service) => _DelayedStartDiscovery(service, gate.future),
        );
        container.read(autoConnectControllerProvider.notifier).activate();
        async.elapse(const Duration(seconds: 20));

        gate.complete();
        async.flushMicrotasks();
        container
            .read(diveComputerServiceProvider)
            .onDeviceDiscovered(advert('NEW'));
        async.elapse(const Duration(seconds: 1));
        expect(requested, isEmpty);

        async.elapse(const Duration(seconds: 14));
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
        service.onDeviceDiscovered(advert('NEW'));
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
          .onDeviceDiscovered(advert('AA'));
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
      service.onDeviceDiscovered(advert('AA'));
      service.onDeviceDiscovered(advert('NEW'));
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
          .onDeviceDiscovered(advert('AA'));
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
      service.onDeviceDiscovered(advert('AA'));
      await pumpEventQueue();
      expect(requested, ['mine']);

      controller.release();
      controller.activate();
      await pumpEventQueue();
      service.onDeviceDiscovered(advert('AA'));
      await pumpEventQueue();

      expect(requested, ['mine']);
    });

    test('two computers of one model, neither at its address: the one '
        'device of that model opens neither', () async {
      final container = makeContainer(
        computers: [perdix('first', 'OLD1'), perdix('second', 'OLD2')],
      );
      container.read(autoConnectControllerProvider.notifier).activate();
      await pumpEventQueue();

      container
          .read(diveComputerServiceProvider)
          .onDeviceDiscovered(advert('NEW'));
      await pumpEventQueue();

      expect(requested, isEmpty);
    });

    test('a record of the same model no scan can reach leaves the match '
        'alone', () async {
      final container = makeContainer(
        computers: [
          perdix('rotated', 'OLD'),
          // Imported from a file: no transport, so never a scan target.
          knownComputer('file', manufacturer: 'Shearwater', model: 'Perdix'),
        ],
      );
      container.read(autoConnectControllerProvider.notifier).activate();
      await pumpEventQueue();

      container
          .read(diveComputerServiceProvider)
          .onDeviceDiscovered(advert('NEW'));
      await pumpEventQueue();

      expect(requested, ['rotated']);
    });
  });
}
