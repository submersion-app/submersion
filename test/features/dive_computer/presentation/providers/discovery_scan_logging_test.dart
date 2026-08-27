import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';

/// Permission backend that answers without a platform channel. Only
/// [requestPermissions] is overridden; the rest of the interface throws by
/// default and is not reached by the discovery flow.
class _FakePermissionHandler extends PermissionHandlerPlatform
    with MockPlatformInterfaceMixin {
  _FakePermissionHandler(this.response);

  final Map<Permission, PermissionStatus> response;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async => response;
}

/// Host API stub that records discovery calls without touching a platform
/// channel. Extends the generated class so only the two methods the
/// discovery flow uses need overriding.
class _FakeHostApi extends pigeon.DiveComputerHostApi {
  bool startDiscoveryCalled = false;
  bool stopDiscoveryCalled = false;
  Object? startDiscoveryError;

  @override
  Future<void> startDiscovery(pigeon.TransportType transport) async {
    startDiscoveryCalled = true;
    final error = startDiscoveryError;
    if (error != null) throw error;
  }

  @override
  Future<void> stopDiscovery() async {
    stopDiscoveryCalled = true;
  }
}

void main() {
  // Issue #123: a Suunto Ocean owner enabled debug mode, ran a scan, and
  // submitted a log containing no Bluetooth lines at all, because the scan
  // path emitted none. These tests pin the boundary logging that makes a
  // scan attempt visible in a submitted debug log.
  group('DiscoveryNotifier scan logging', () {
    late _FakeHostApi hostApi;
    late pigeon.DiveComputerService service;
    late DiscoveryNotifier notifier;
    late List<LogEntry> captured;
    late StreamSubscription<LogEntry> subscription;

    setUp(() {
      hostApi = _FakeHostApi();
      service = pigeon.DiveComputerService(hostApi: hostApi);
      notifier = DiscoveryNotifier(service: service);
      captured = [];
      subscription = LoggerService.logStream.listen(captured.add);
    });

    tearDown(() async {
      await subscription.cancel();
      notifier.dispose();
    });

    List<LogEntry> bluetoothEntries() =>
        captured.where((e) => e.category == LogCategory.bluetooth).toList();

    // LoggerService publishes through a broadcast controller, so listeners
    // are notified on a later microtask than the call that logged.
    Future<void> settle() => pumpEventQueue();

    test('logs a Bluetooth entry when a scan starts', () async {
      await notifier.startScan();
      await settle();

      expect(hostApi.startDiscoveryCalled, isTrue);
      expect(bluetoothEntries(), isNotEmpty);
    });

    test('logs a Bluetooth error when starting discovery throws', () async {
      hostApi.startDiscoveryError = StateError('adapter unavailable');

      await notifier.startScan();
      await settle();

      final errors = bluetoothEntries()
          .where((e) => e.level == LogLevel.error)
          .toList();
      expect(errors, isNotEmpty);
      expect(errors.first.message, contains('adapter unavailable'));
      expect(notifier.state.isScanning, isFalse);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test(
      'drops the device subscription when starting discovery throws',
      () async {
        // The subscription is opened before startDiscovery is awaited, so a
        // synchronous failure would otherwise leave it live and let a stray
        // native event populate the list under an error message.
        hostApi.startDiscoveryError = StateError('adapter unavailable');
        await notifier.startScan();
        await settle();

        service.onDeviceDiscovered(
          pigeon.DiscoveredDevice(
            vendor: 'Suunto',
            product: 'D5',
            model: 2,
            address: 'AA:BB:CC:DD:EE:FF',
            name: 'Suunto D5',
            transport: pigeon.TransportType.ble,
          ),
        );
        await settle();

        expect(notifier.state.discoveredDevices, isEmpty);
      },
    );

    group('runtime permission gate', () {
      late PermissionHandlerPlatform original;

      setUp(() => original = PermissionHandlerPlatform.instance);
      tearDown(() => PermissionHandlerPlatform.instance = original);

      DiscoveryNotifier gatedNotifier() {
        final gated = DiscoveryNotifier(
          service: service,
          requiresRuntimePermissions: true,
        );
        addTearDown(gated.dispose);
        return gated;
      }

      test('logs and blocks the scan when a permission is refused', () async {
        PermissionHandlerPlatform.instance = _FakePermissionHandler({
          Permission.bluetoothScan: PermissionStatus.denied,
          Permission.bluetoothConnect: PermissionStatus.granted,
        });
        final gated = gatedNotifier();

        await gated.startScan();
        await settle();

        expect(hostApi.startDiscoveryCalled, isFalse);
        expect(gated.state.isScanning, isFalse);
        expect(gated.state.errorMessage, isNotNull);

        final warnings = bluetoothEntries()
            .where((e) => e.level == LogLevel.warning)
            .toList();
        expect(warnings, isNotEmpty);
        expect(warnings.first.message, contains('denied'));
      });

      test('proceeds to scan once every permission is granted', () async {
        PermissionHandlerPlatform.instance = _FakePermissionHandler({
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
        });
        final gated = gatedNotifier();

        await gated.startScan();
        await settle();

        expect(hostApi.startDiscoveryCalled, isTrue);
        expect(gated.state.isScanning, isTrue);
        expect(gated.state.errorMessage, isNull);
      });
    });

    test('logs a Bluetooth entry when a scan stops', () async {
      await notifier.startScan();
      await settle();
      captured.clear();

      await notifier.stopScan();
      await settle();

      expect(hostApi.stopDiscoveryCalled, isTrue);
      expect(bluetoothEntries(), isNotEmpty);
    });

    test('logs each device the native scanner surfaces', () async {
      await notifier.startScan();
      await settle();
      captured.clear();

      service.onDeviceDiscovered(
        pigeon.DiscoveredDevice(
          vendor: 'Suunto',
          product: 'D5',
          model: 2,
          address: 'AA:BB:CC:DD:EE:FF',
          name: 'Suunto D5',
          transport: pigeon.TransportType.ble,
        ),
      );
      await settle();

      expect(notifier.state.discoveredDevices, hasLength(1));
      final messages = bluetoothEntries().map((e) => e.message).join('\n');
      expect(messages, contains('Suunto D5'));
    });
  });
}
