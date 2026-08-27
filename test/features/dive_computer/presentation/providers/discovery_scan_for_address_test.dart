import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';

/// Host API stub that records discovery calls without touching a platform
/// channel.
class _FakeHostApi extends pigeon.DiveComputerHostApi {
  int startDiscoveryCalls = 0;
  int stopDiscoveryCalls = 0;
  Object? startDiscoveryError;

  @override
  Future<void> startDiscovery(pigeon.TransportType transport) async {
    startDiscoveryCalls++;
    final error = startDiscoveryError;
    if (error != null) throw error;
  }

  @override
  Future<void> stopDiscovery() async {
    stopDiscoveryCalls++;
  }
}

const _savedAddress = 'E8:F8:BE:96:61:57';

pigeon.DiscoveredDevice _advert(String address) => pigeon.DiscoveredDevice(
  vendor: 'Shearwater',
  product: 'Petrel 3',
  model: 10,
  address: address,
  name: 'Petrel 3',
  transport: pigeon.TransportType.ble,
);

void main() {
  // Issue #1232: a download started from a saved computer connected straight
  // to the stored address with no scan, which fails on Android and Windows
  // when the stack has not seen the device advertise recently. This is the
  // scan-then-resolve primitive the saved-computer path uses to re-acquire
  // the device first.
  group('DiscoveryNotifier.scanForAddress', () {
    late _FakeHostApi hostApi;
    late pigeon.DiveComputerService service;
    late DiscoveryNotifier notifier;

    setUp(() {
      hostApi = _FakeHostApi();
      service = pigeon.DiveComputerService(hostApi: hostApi);
      notifier = DiscoveryNotifier(
        service: service,
        requiresRuntimePermissions: false,
      );
    });

    tearDown(() {
      notifier.dispose();
    });

    test(
      'resolves the device advertising the saved address and stops the scan',
      () async {
        final pending = notifier.scanForAddress(
          _savedAddress,
          timeout: const Duration(seconds: 5),
        );
        await pumpEventQueue();
        expect(hostApi.startDiscoveryCalls, 1);

        service.onDeviceDiscovered(_advert('11:22:33:44:55:66'));
        service.onDeviceDiscovered(_advert(_savedAddress));

        final device = await pending;
        expect(device, isNotNull);
        expect(device!.address, _savedAddress);
        expect(device.recognizedModel?.manufacturer, 'Shearwater');
        expect(device.recognizedModel?.model, 'Petrel 3');
        expect(hostApi.stopDiscoveryCalls, 1);
        expect(notifier.state.isScanning, isFalse);
      },
    );

    test('matches the saved address regardless of letter case', () async {
      final pending = notifier.scanForAddress(
        _savedAddress.toLowerCase(),
        timeout: const Duration(seconds: 5),
      );
      await pumpEventQueue();

      service.onDeviceDiscovered(_advert(_savedAddress));

      final device = await pending;
      expect(device?.address, _savedAddress);
    });

    test('returns null and stops the scan when the address is not seen '
        'before the timeout', () async {
      final pending = notifier.scanForAddress(
        _savedAddress,
        timeout: const Duration(milliseconds: 50),
      );
      await pumpEventQueue();
      service.onDeviceDiscovered(_advert('11:22:33:44:55:66'));

      final device = await pending;
      expect(device, isNull);
      expect(hostApi.stopDiscoveryCalls, 1);
      expect(notifier.state.isScanning, isFalse);
    });

    test('returns null without waiting when the scan cannot start', () async {
      hostApi.startDiscoveryError = StateError('adapter unavailable');

      // A generous timeout: the call must give up on the start failure,
      // not sit out the timeout.
      final device = await notifier
          .scanForAddress(_savedAddress, timeout: const Duration(minutes: 5))
          .timeout(const Duration(seconds: 2));

      expect(device, isNull);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test(
      'returns null when native discovery completes without the device',
      () async {
        final pending = notifier
            .scanForAddress(_savedAddress, timeout: const Duration(minutes: 5))
            .timeout(const Duration(seconds: 2));
        await pumpEventQueue();

        service.onDiscoveryComplete();

        expect(await pending, isNull);
      },
    );
  });
}
