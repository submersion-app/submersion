import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_step_widget.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_steps.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_no_direct_download_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_import_adapter_deps.dart';

// Issue #1858: a saved computer with no stored connection (a Garmin watch,
// a cloud or file-imported computer) has nothing to build a download device
// from. The step used to hand DownloadStepWidget a null device, which never
// starts and never errors, so "Preparing..." spun forever.

class _RecordingHostApi extends pigeon.DiveComputerHostApi {
  final List<String> calls = [];

  @override
  Future<void> startDiscovery(pigeon.TransportType transport) async {
    calls.add('startDiscovery');
  }

  @override
  Future<void> stopDiscovery() async {
    calls.add('stopDiscovery');
  }

  @override
  Future<void> startDownload(
    pigeon.DiscoveredDevice device,
    String? fingerprint,
    bool syncClock,
  ) async {
    calls.add('startDownload');
  }

  @override
  Future<List<pigeon.DeviceDescriptor>> getDeviceDescriptors() async => [];

  @override
  Future<String> getLibdivecomputerVersion() async => '0.0.0';
}

class _IdleDiscoveryNotifier extends DiscoveryNotifier {
  _IdleDiscoveryNotifier({required super.service})
    : super(requiresRuntimePermissions: false);
}

DiveComputer _computer({
  required String manufacturer,
  required String model,
  String? connectionType,
  String? bluetoothAddress,
}) {
  final now = DateTime(2026, 10, 2);
  return DiveComputer(
    id: 'dc-1',
    diverId: 'diver-1',
    name: '$manufacturer $model',
    manufacturer: manufacturer,
    model: model,
    connectionType: connectionType,
    bluetoothAddress: bluetoothAddress,
    createdAt: now,
    updatedAt: now,
  );
}

/// A computer added over a USB cable on a desktop.
///
/// On that desktop it carries the port it was reached on. Sync strips the
/// port (it is host-local, `SyncDataSerializer` drops `bluetoothAddress`), so
/// the copy that arrives on another device has `connectionType: 'usb'` and no
/// stored address: pass no [port] for that shape.
DiveComputer _usbComputer({String? port}) => _computer(
  manufacturer: 'Suunto',
  model: 'Vyper',
  connectionType: 'usb',
  bluetoothAddress: port,
);

const _usbExplanation =
    'Suunto Vyper connects with a USB cable, which Submersion cannot use on '
    'iPhone or iPad. Download its dives with Submersion on a Mac, Windows or '
    'Linux computer, or import them from a file.';

class _Harness {
  _Harness() : hostApi = _RecordingHostApi() {
    service = pigeon.DiveComputerService(hostApi: hostApi);
  }

  final _RecordingHostApi hostApi;
  final FakeImportAdapterDeps deps = FakeImportAdapterDeps();
  late final pigeon.DiveComputerService service;

  Widget build(DiveComputer computer) {
    final adapter = DiveComputerAdapter(
      importService: deps.importService,
      computerRepository: deps.computerRepo,
      diveRepository: deps.diveRepo,
      consolidationService: deps.consolidationService,
      diverId: 'diver-1',
      knownComputer: computer,
    );
    // The step sits on top of a parent page, as the real download route
    // does, so Done has somewhere to pop back to.
    final router = GoRouter(
      initialLocation: '/computer/download',
      routes: [
        GoRoute(
          path: '/computer',
          builder: (context, state) =>
              const Scaffold(body: Text('computer detail route')),
          routes: [
            GoRoute(
              path: 'download',
              builder: (context, state) => Scaffold(
                body: DcAdapterDownloadStep(
                  adapter: adapter,
                  knownComputer: computer,
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/transfer/import-wizard',
          builder: (context, state) =>
              const Scaffold(body: Text('import wizard route')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        diveComputerServiceProvider.overrideWithValue(service),
        discoveryNotifierProvider.overrideWith(
          (ref) => _IdleDiscoveryNotifier(service: service),
        ),
        diveComputerRepositoryProvider.overrideWithValue(deps.computerRepo),
        deviceDescriptorsProvider.overrideWith((ref) async => []),
        firstSyncCutoffDefaultProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'a saved USB Garmin with no stored connection explains FIT import '
    'instead of spinning on Preparing',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(
        harness.build(
          _computer(
            manufacturer: 'Garmin',
            model: 'Descent G2',
            connectionType: 'usb',
          ),
        ),
      );
      await _settle(tester);

      expect(find.byType(DownloadStepWidget), findsNothing);
      expect(find.text('Preparing...'), findsNothing);
      expect(find.byType(DcNoDirectDownloadView), findsOneWidget);
      expect(
        find.textContaining('GARMIN/Activity'),
        findsOneWidget,
        reason: 'a Garmin computer gets the FIT-file guidance',
      );
      expect(harness.hostApi.calls, isNot(contains('startDownload')));
    },
  );

  testWidgets(
    'a cloud computer with no stored connection gets the generic explanation',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(
        harness.build(
          _computer(
            manufacturer: 'Suunto',
            model: 'EON Core',
            connectionType: 'cloud',
          ),
        ),
      );
      await _settle(tester);

      expect(find.byType(DownloadStepWidget), findsNothing);
      expect(find.byType(DcNoDirectDownloadView), findsOneWidget);
      expect(find.textContaining('GARMIN/Activity'), findsNothing);
      expect(find.textContaining('Suunto EON Core'), findsOneWidget);
      expect(harness.hostApi.calls, isNot(contains('startDownload')));
    },
  );

  testWidgets('Import from File opens the file import wizard', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(
      harness.build(
        _computer(
          manufacturer: 'Garmin',
          model: 'Descent G2',
          connectionType: 'usb',
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Import from File'));
    await tester.pumpAndSettle();

    expect(find.text('import wizard route'), findsOneWidget);
  });

  // Issue #2837: iOS has no USB host. A USB computer saved on a desktop
  // syncs to iOS, and downloading it there either fell through to the
  // generic "no saved connection" text (sync strips the port) or, with a
  // port, reached the native layer and failed with "No USB serial ports
  // found".
  group('a saved USB computer', () {
    testWidgets('synced to iOS explains that USB needs a desktop', (
      tester,
    ) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build(_usbComputer()));
      await _settle(tester);

      expect(find.byType(DownloadStepWidget), findsNothing);
      expect(find.byType(DcNoDirectDownloadView), findsOneWidget);
      expect(find.text(_usbExplanation), findsOneWidget);
      expect(harness.hostApi.calls, isNot(contains('startDownload')));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets(
      'synced to iOS: Import from File opens the file import wizard',
      (tester) async {
        final harness = _Harness();
        await tester.pumpWidget(harness.build(_usbComputer()));
        await _settle(tester);

        await tester.tap(find.text('Import from File'));
        await tester.pumpAndSettle();

        expect(find.text('import wizard route'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('synced to iOS: Done leaves for the page it came from', (
      tester,
    ) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build(_usbComputer()));
      await _settle(tester);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.byType(DcNoDirectDownloadView), findsNothing);
      expect(find.text('computer detail route'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('with a stored port on iOS explains instead of downloading', (
      tester,
    ) async {
      final harness = _Harness();
      await tester.pumpWidget(
        harness.build(_usbComputer(port: '/dev/cu.usbserial-A10')),
      );
      await _settle(tester);

      expect(find.byType(DownloadStepWidget), findsNothing);
      expect(find.text(_usbExplanation), findsOneWidget);
      expect(harness.hostApi.calls, isNot(contains('startDownload')));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('on a platform with a USB host still downloads', (
      tester,
    ) async {
      final harness = _Harness();
      await tester.pumpWidget(
        harness.build(_usbComputer(port: '/dev/cu.usbserial-A10')),
      );
      await _settle(tester);

      expect(find.byType(DcNoDirectDownloadView), findsNothing);
      expect(find.byType(DownloadStepWidget), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      'without a stored connection on iOS keeps the Garmin FIT guidance',
      (tester) async {
        final harness = _Harness();
        await tester.pumpWidget(
          harness.build(
            _computer(
              manufacturer: 'Garmin',
              model: 'Descent G2',
              connectionType: 'usb',
            ),
          ),
        );
        await _settle(tester);

        expect(find.textContaining('GARMIN/Activity'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });

  testWidgets('Done leaves the download for the page it came from', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(
      harness.build(
        _computer(
          manufacturer: 'Garmin',
          model: 'Descent G2',
          connectionType: 'usb',
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(DcNoDirectDownloadView), findsNothing);
    expect(find.text('computer detail route'), findsOneWidget);
  });
}
