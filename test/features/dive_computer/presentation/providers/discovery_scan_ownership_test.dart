import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';

/// Permission backend whose answer the test releases, the way Android's
/// runtime prompt holds a scan start open.
class _HeldPermissionHandler extends PermissionHandlerPlatform
    with MockPlatformInterfaceMixin {
  final answer = Completer<Map<Permission, PermissionStatus>>();

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) => answer.future;
}

/// Host API stub counting discovery calls. [stopGate], when set, holds the
/// native stop open until the test completes it.
class _FakeHostApi extends pigeon.DiveComputerHostApi {
  int startDiscoveryCalls = 0;
  int stopDiscoveryCalls = 0;
  Completer<void>? stopGate;

  @override
  Future<void> startDiscovery(pigeon.TransportType transport) async {
    startDiscoveryCalls++;
  }

  @override
  Future<void> stopDiscovery() async {
    stopDiscoveryCalls++;
    final gate = stopGate;
    if (gate != null) await gate.future;
  }
}

void main() {
  // Issue #3361: every flow shares one DiscoveryNotifier, so stopping a scan
  // must only ever stop the scan its caller started.
  group('DiscoveryNotifier scan ownership', () {
    late _FakeHostApi hostApi;
    late pigeon.DiveComputerService service;
    late DiscoveryNotifier notifier;
    final owner = Object();

    setUp(() {
      hostApi = _FakeHostApi();
      service = pigeon.DiveComputerService(hostApi: hostApi);
      notifier = DiscoveryNotifier(
        service: service,
        requiresRuntimePermissions: false,
      );
    });

    tearDown(() => notifier.dispose());

    test('stopScan leaves a scan an owner started running', () async {
      await notifier.startScan(owner: owner);

      await notifier.stopScan();

      expect(hostApi.stopDiscoveryCalls, 0);
      expect(notifier.state.isScanning, isTrue);
    });

    test('stopScanOwnedBy stops its own scan and no other', () async {
      await notifier.startScan(owner: owner);

      await notifier.stopScanOwnedBy(Object());
      expect(hostApi.stopDiscoveryCalls, 0);

      await notifier.stopScanOwnedBy(owner);
      expect(hostApi.stopDiscoveryCalls, 1);
      expect(notifier.state.isScanning, isFalse);
    });

    test('a stop finishing late does not end a scan started '
        'meanwhile', () async {
      await notifier.startScan();
      hostApi.stopGate = Completer<void>();

      final stopping = notifier.stopScan();
      await notifier.startScan();
      hostApi.stopGate!.complete();
      await stopping;

      expect(notifier.state.isScanning, isTrue);
    });

    group('with the runtime permission prompt', () {
      late PermissionHandlerPlatform original;

      setUp(() => original = PermissionHandlerPlatform.instance);
      tearDown(() => PermissionHandlerPlatform.instance = original);

      test('a start still waiting on the prompt does not begin a scan that '
          'was stopped meanwhile', () async {
        final handler = _HeldPermissionHandler();
        PermissionHandlerPlatform.instance = handler;
        final gated = DiscoveryNotifier(
          service: service,
          requiresRuntimePermissions: true,
        );
        addTearDown(gated.dispose);

        final starting = gated.startScan(owner: owner);
        await gated.stopScanOwnedBy(owner);
        handler.answer.complete({
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
        });
        await starting;

        expect(hostApi.startDiscoveryCalls, 0);
        expect(gated.state.isScanning, isFalse);
      });
    });
  });
}
