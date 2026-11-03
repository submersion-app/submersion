import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';

/// Host API stub counting native scan starts.
class _FakeHostApi extends pigeon.DiveComputerHostApi {
  int startDiscoveryCalls = 0;

  @override
  Future<void> startDiscovery(pigeon.TransportType transport) async {
    startDiscoveryCalls++;
  }

  @override
  Future<void> stopDiscovery() async {}
}

void main() {
  // Android starts at most five BLE scans per app in 30 seconds and gives a
  // sixth no results, with no error. The passive auto-connect scan restarts
  // on every return to the Dive Computers section (issue #3361), so a few
  // quick visits could leave a wizard's scan empty.
  group('DiscoveryNotifier paces BLE scan starts', () {
    late _FakeHostApi hostApi;

    DiscoveryNotifier notifierFor({required bool paceScanStarts}) {
      hostApi = _FakeHostApi();
      return DiscoveryNotifier(
        service: pigeon.DiveComputerService(hostApi: hostApi),
        requiresRuntimePermissions: false,
        paceScanStarts: paceScanStarts,
      );
    }

    /// Starts five scans a second apart, the most Android allows in 30 s.
    void startFive(FakeAsync async, DiscoveryNotifier notifier) {
      for (var i = 0; i < DiscoveryNotifier.scanStartLimit; i++) {
        notifier.startScan();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
      }
    }

    test('a sixth start in 30 seconds waits for the oldest to age out', () {
      fakeAsync((async) {
        final notifier = notifierFor(paceScanStarts: true);
        startFive(async, notifier);
        expect(hostApi.startDiscoveryCalls, 5);

        // At t=5 s; the first start ages out at t=30 s, plus a second's
        // margin for Android's own clock.
        notifier.startScan();
        async.flushMicrotasks();
        expect(hostApi.startDiscoveryCalls, 5);
        expect(notifier.state.isScanning, isTrue);

        async.elapse(const Duration(seconds: 25));
        expect(hostApi.startDiscoveryCalls, 5);
        async.elapse(const Duration(seconds: 1));
        expect(hostApi.startDiscoveryCalls, 6);
        notifier.dispose();
      });
    });

    test('a scan stopped while it waits never starts', () {
      fakeAsync((async) {
        final notifier = notifierFor(paceScanStarts: true);
        startFive(async, notifier);

        notifier.startScan();
        async.flushMicrotasks();
        notifier.stopScan();
        async.elapse(const Duration(minutes: 1));

        expect(hostApi.startDiscoveryCalls, 5);
        expect(notifier.state.isScanning, isFalse);
        notifier.dispose();
      });
    });

    test('starts spread over more than 30 seconds never wait', () {
      fakeAsync((async) {
        final notifier = notifierFor(paceScanStarts: true);
        for (var i = 0; i < 8; i++) {
          notifier.startScan();
          async.flushMicrotasks();
          expect(hostApi.startDiscoveryCalls, i + 1);
          async.elapse(const Duration(seconds: 7));
        }
        notifier.dispose();
      });
    });

    test('a clock set back does not hold a start for the size of the jump', () {
      fakeAsync((async) {
        var now = DateTime.utc(2026, 11, 3, 12);
        withClock(Clock(() => now), () {
          final notifier = notifierFor(paceScanStarts: true);
          for (var i = 0; i < DiscoveryNotifier.scanStartLimit; i++) {
            notifier.startScan();
            async.flushMicrotasks();
          }
          expect(hostApi.startDiscoveryCalls, 5);

          // A manual change or a network time correction.
          now = now.subtract(const Duration(hours: 1));
          notifier.startScan();
          async.flushMicrotasks();

          expect(hostApi.startDiscoveryCalls, 6);
          notifier.dispose();
        });
      });
    });

    test('a platform that does not throttle starts every scan at once', () {
      fakeAsync((async) {
        final notifier = notifierFor(paceScanStarts: false);
        startFive(async, notifier);

        notifier.startScan();
        async.flushMicrotasks();

        expect(hostApi.startDiscoveryCalls, 6);
        notifier.dispose();
      });
    });
  });
}
