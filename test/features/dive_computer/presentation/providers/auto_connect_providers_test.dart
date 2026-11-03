import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_settings_provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

import 'auto_connect_test_support.dart';

void main() {
  late FakeHostApi hostApi;
  late FakeDownloadNotifier downloadNotifier;
  late List<String> requested;

  ProviderContainer makeContainer({
    List<DiveComputer> computers = const [],
    bool autoConnectEnabled = true,
    bool failToReadComputers = false,
    Duration modelMatchWindow = Duration.zero,
    DiscoveryNotifier Function(pigeon.DiveComputerService service)? discovery,
  }) {
    final harness = buildAutoConnectHarness(
      computers: computers,
      autoConnectEnabled: autoConnectEnabled,
      failToReadComputers: failToReadComputers,
      modelMatchWindow: modelMatchWindow,
      discovery: discovery,
    );
    hostApi = harness.hostApi;
    downloadNotifier = harness.downloadNotifier;
    requested = harness.requested;
    return harness.container;
  }

  test('switch off: activate() does not start a scan', () async {
    final container = makeContainer(
      computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
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
      computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);

    controller.activate();
    await pumpEventQueue();
    expect(hostApi.startDiscoveryCalls, 1);

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(advert('11:22:33:44:55:66'));
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
      computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(advert('11:22:33:44:55:66'));
    await pumpEventQueue();
    service.onDeviceDiscovered(advert('11:22:33:44:55:66'));
    await pumpEventQueue();

    expect(requested, ['c1']);
  });

  test('a scan that fails to start stops showing as searching, and the '
      'next activate() tries again', () async {
    final container = makeContainer(
      computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
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
      computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
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
      computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(advert('11:22:33:44:55:66'));
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
        knownComputer(
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
        knownComputer(
          'c1',
          bluetoothAddress: '11:22:33:44:55:66',
          autoDownloadDisabled: true,
        ),
        // Keeps the scan running, so the opted-out computer is seen.
        knownComputer('c2', bluetoothAddress: '99:99:99:99:99:99'),
      ],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(advert('11:22:33:44:55:66'));
    await pumpEventQueue();

    expect(requested, isEmpty);
  });

  test('a manual download already in progress suppresses the auto-trigger '
      'for that cycle', () async {
    final container = makeContainer(
      computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    downloadNotifier.markDownloading();
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(advert('11:22:33:44:55:66'));
    await pumpEventQueue();

    expect(requested, isEmpty);
  });

  test('a download finishing elsewhere re-runs matching without a new scan '
      'event', () async {
    final container = makeContainer(
      computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    downloadNotifier.markDownloading();
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(advert('11:22:33:44:55:66'));
    await pumpEventQueue();
    expect(requested, isEmpty);

    downloadNotifier.finish();
    await pumpEventQueue();

    expect(requested, ['c1']);
  });

  test('release() stops its own scan without notifying listeners, so it is '
      "safe from the hosting widget's dispose", () async {
    final container = makeContainer(
      computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
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
      computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    service.onDeviceDiscovered(advert('11:22:33:44:55:66'));
    await pumpEventQueue();
    expect(requested, ['c1']);

    // The download page covers the section, then is closed again.
    controller.release();
    controller.activate();
    await pumpEventQueue();
    expect(hostApi.startDiscoveryCalls, 2);
    service.onDeviceDiscovered(advert('11:22:33:44:55:66'));
    await pumpEventQueue();
    expect(requested, ['c1']);

    // Leaving the section disposes the controller; the next visit re-arms.
    container.invalidate(autoConnectControllerProvider);
    container.read(autoConnectControllerProvider.notifier).activate();
    await pumpEventQueue();
    service.onDeviceDiscovered(advert('11:22:33:44:55:66'));
    await pumpEventQueue();

    expect(requested, ['c1', 'c1']);
  });

  test('two known computers reachable: requested one at a time, in the '
      'order they were discovered', () async {
    final container = makeContainer(
      computers: [
        knownComputer('a', bluetoothAddress: '11:11:11:11:11:11'),
        knownComputer('b', bluetoothAddress: '22:22:22:22:22:22'),
      ],
    );
    final controller = container.read(autoConnectControllerProvider.notifier);
    controller.activate();
    await pumpEventQueue();

    final service = container.read(diveComputerServiceProvider);
    // B is found first although A comes first in the computer list, and
    // both arrive before the controller's first match pass completes.
    service.onDeviceDiscovered(advert('22:22:22:22:22:22', name: 'B'));
    service.onDeviceDiscovered(advert('11:11:11:11:11:11', name: 'A'));
    await pumpEventQueue();

    expect(requested, ['b']);

    // B's download page is closed again; A is still in range.
    controller.release();
    controller.activate();
    await pumpEventQueue();
    service.onDeviceDiscovered(advert('11:11:11:11:11:11', name: 'A'));
    service.onDeviceDiscovered(advert('22:22:22:22:22:22', name: 'B'));
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
    service.onDeviceDiscovered(advert('11:22:33:44:55:66'));
    await pumpEventQueue();

    expect(requested, isEmpty);
  });

  test(
    'flipping the switch off while scanning stops the scan right away',
    () async {
      final container = makeContainer(
        computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
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
      computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
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
    late GatedDiscoveryNotifier discovery;
    final container = makeContainer(
      computers: [knownComputer('c1', bluetoothAddress: '11:22:33:44:55:66')],
      discovery: (service) => discovery = GatedDiscoveryNotifier(service),
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
}
