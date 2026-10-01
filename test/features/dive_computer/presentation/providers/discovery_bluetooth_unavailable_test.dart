import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';

/// Host API stub whose startDiscovery fails with [startDiscoveryError] until
/// it is cleared.
class _FakeHostApi extends pigeon.DiveComputerHostApi {
  Object? startDiscoveryError;

  @override
  Future<void> startDiscovery(pigeon.TransportType transport) async {
    final error = startDiscoveryError;
    if (error != null) throw error;
  }

  @override
  Future<void> stopDiscovery() async {}
}

void main() {
  // Issue #2507: on Windows with the Bluetooth radio off, starting a BLE scan
  // aborted the whole app. The native side now answers with the
  // bluetooth_unavailable code instead, and the scan step needs to know that
  // was the reason so it can say so in the user's language.
  group('DiscoveryNotifier when Bluetooth is unavailable', () {
    late _FakeHostApi hostApi;
    late DiscoveryNotifier notifier;

    setUp(() {
      hostApi = _FakeHostApi();
      notifier = DiscoveryNotifier(
        service: pigeon.DiveComputerService(hostApi: hostApi),
      );
    });

    tearDown(() => notifier.dispose());

    test('flags the state when the native code says so', () async {
      hostApi.startDiscoveryError = PlatformException(
        code: pigeon.bluetoothUnavailableErrorCode,
        message: 'Bluetooth is unavailable: The device is not ready for use.',
      );

      await notifier.startScan();

      expect(notifier.state.bluetoothUnavailable, isTrue);
      expect(notifier.state.isScanning, isFalse);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('leaves the flag clear for any other start failure', () async {
      hostApi.startDiscoveryError = PlatformException(
        code: 'discovery_error',
        message: 'Failed to start discovery',
      );

      await notifier.startScan();

      expect(notifier.state.bluetoothUnavailable, isFalse);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('clears the flag once a retried scan starts', () async {
      hostApi.startDiscoveryError = PlatformException(
        code: pigeon.bluetoothUnavailableErrorCode,
      );
      await notifier.startScan();
      expect(notifier.state.bluetoothUnavailable, isTrue);

      hostApi.startDiscoveryError = null;
      await notifier.startScan();

      expect(notifier.state.bluetoothUnavailable, isFalse);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.isScanning, isTrue);
    });
  });

  group('DiscoveryState.copyWith', () {
    test('a new error message drops a stale Bluetooth-off flag', () {
      const bluetoothOff = DiscoveryState(
        errorMessage: 'Bluetooth is unavailable',
        bluetoothUnavailable: true,
      );

      final next = bluetoothOff.copyWith(errorMessage: 'Permissions denied');

      expect(next.bluetoothUnavailable, isFalse);
      expect(next.errorMessage, 'Permissions denied');
    });

    test('an unrelated update keeps the flag', () {
      const bluetoothOff = DiscoveryState(
        errorMessage: 'Bluetooth is unavailable',
        bluetoothUnavailable: true,
      );

      expect(
        bluetoothOff.copyWith(isScanning: false).bluetoothUnavailable,
        isTrue,
      );
    });
  });
}
