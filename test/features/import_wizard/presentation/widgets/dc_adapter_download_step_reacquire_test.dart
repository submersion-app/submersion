import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_step_widget.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_steps.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_import_adapter_deps.dart';

// ---------------------------------------------------------------------------
// Fake host API: records the order of native calls and what startDownload
// received, without touching a platform channel.
// ---------------------------------------------------------------------------

class _RecordingHostApi extends pigeon.DiveComputerHostApi {
  final List<String> calls = [];
  final List<pigeon.DiscoveredDevice> downloads = [];

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
  ) async {
    calls.add('startDownload');
    downloads.add(device);
  }

  @override
  Future<List<pigeon.DeviceDescriptor>> getDeviceDescriptors() async => [];

  @override
  Future<String> getLibdivecomputerVersion() async => '0.0.0';
}

/// Discovery notifier whose initial state is chosen by the test.
class _SeededDiscoveryNotifier extends DiscoveryNotifier {
  _SeededDiscoveryNotifier({
    required super.service,
    required DiscoveryState seed,
  }) : super(requiresRuntimePermissions: false) {
    state = seed;
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _savedAddress = 'E8:F8:BE:96:61:57';

DiveComputer _savedComputer({
  String connectionType = 'bluetooth',
  String bluetoothAddress = _savedAddress,
}) {
  final now = DateTime(2026, 8, 23);
  return DiveComputer(
    id: 'dc-1',
    diverId: 'diver-1',
    name: 'My Petrel',
    manufacturer: 'Shearwater',
    model: 'Petrel 3',
    connectionType: connectionType,
    bluetoothAddress: bluetoothAddress,
    lastDiveFingerprint: 'abc',
    createdAt: now,
    updatedAt: now,
  );
}

pigeon.DiscoveredDevice _advert(String address) => pigeon.DiscoveredDevice(
  vendor: 'Shearwater',
  product: 'Petrel 3',
  model: 10,
  address: address,
  name: 'Petrel 3',
  transport: pigeon.TransportType.ble,
);

DiscoveredDevice _discovered(String address) => DiscoveredDevice(
  id: 'seeded',
  name: 'Petrel 3',
  connectionType: DeviceConnectionType.ble,
  address: address,
  recognizedModel: const DeviceModel(
    id: 'shearwater_petrel3',
    manufacturer: 'Shearwater',
    model: 'Petrel 3',
    connectionTypes: [DeviceConnectionType.ble],
    dcModel: 10,
  ),
  discoveredAt: DateTime(2026, 8, 23),
);

class _Harness {
  _Harness({DiscoveryState seed = const DiscoveryState()})
    : hostApi = _RecordingHostApi(),
      _seed = seed {
    service = pigeon.DiveComputerService(hostApi: hostApi);
  }

  final _RecordingHostApi hostApi;
  final DiscoveryState _seed;
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
    return ProviderScope(
      overrides: [
        diveComputerServiceProvider.overrideWithValue(service),
        discoveryNotifierProvider.overrideWith(
          (ref) => _SeededDiscoveryNotifier(service: service, seed: _seed),
        ),
        diveComputerRepositoryProvider.overrideWithValue(deps.computerRepo),
        deviceDescriptorsProvider.overrideWith((ref) async => []),
        firstSyncCutoffDefaultProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DcAdapterDownloadStep(
            adapter: adapter,
            knownComputer: computer,
          ),
        ),
      ),
    );
  }
}

/// The step settles through several async gates (scan resolution, descriptor
/// lookup, the download widget's post-frame auto-start); a handful of plain
/// pumps covers them. pumpAndSettle cannot be used because the download
/// widget shows an indeterminate progress indicator.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

/// The device currently selected in the discovery provider the step reads.
DiscoveredDevice? _selectedDevice(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(DcAdapterDownloadStep)),
    ).read(discoveryNotifierProvider).selectedDevice;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Issue #1232: tapping a saved Petrel 3 and downloading failed with
  // connect_failed on Android and Windows, while the scan-and-download flow
  // for the very same computer worked. The saved-computer path connected to
  // the stored address without a preceding scan; it now re-acquires the
  // device by scanning for that address first.
  group('DcAdapterDownloadStep saved-computer re-acquisition', () {
    testWidgets(
      'scans for the saved address and downloads from the advertised device',
      (tester) async {
        final h = _Harness();
        await tester.pumpWidget(h.build(_savedComputer()));
        await tester.pump();

        expect(h.hostApi.calls, ['startDiscovery']);
        expect(find.text('Searching for My Petrel...'), findsOneWidget);
        expect(find.byType(DownloadStepWidget), findsNothing);

        h.service.onDeviceDiscovered(_advert('11:22:33:44:55:66'));
        h.service.onDeviceDiscovered(_advert(_savedAddress));
        await _settle(tester);

        expect(h.hostApi.calls, [
          'startDiscovery',
          'stopDiscovery',
          'startDownload',
        ]);
        final sent = h.hostApi.downloads.single;
        expect(sent.address, _savedAddress);
        // The freshly advertised device carries the descriptor the driver
        // needs, which the synthesized fallback could only guess at.
        expect(sent.vendor, 'Shearwater');
        expect(sent.product, 'Petrel 3');
        expect(sent.model, 10);
      },
    );

    testWidgets(
      'falls back to the stored address when the scan does not see the '
      'device',
      (tester) async {
        final h = _Harness();
        await tester.pumpWidget(h.build(_savedComputer()));
        await tester.pump();
        expect(h.hostApi.calls, ['startDiscovery']);

        await tester.pump(
          DcAdapterDownloadStep.knownDeviceScanTimeout +
              const Duration(seconds: 1),
        );
        await _settle(tester);

        expect(h.hostApi.calls, [
          'startDiscovery',
          'stopDiscovery',
          'startDownload',
        ]);
        expect(h.hostApi.downloads.single.address, _savedAddress);
      },
    );

    testWidgets('does not scan when discovery already holds the device for the '
        'saved address', (tester) async {
      final h = _Harness(
        seed: DiscoveryState(selectedDevice: _discovered(_savedAddress)),
      );
      await tester.pumpWidget(h.build(_savedComputer()));
      await _settle(tester);

      expect(h.hostApi.calls, ['startDownload']);
      expect(h.hostApi.downloads.single.address, _savedAddress);
    });

    testWidgets(
      'ignores a previously selected device with a different address',
      (tester) async {
        final h = _Harness(
          seed: DiscoveryState(
            selectedDevice: _discovered('11:22:33:44:55:66'),
          ),
        );
        await tester.pumpWidget(h.build(_savedComputer()));
        await tester.pump();

        expect(h.hostApi.calls, ['startDiscovery']);
        expect(find.byType(DownloadStepWidget), findsNothing);
        // The stale selection is dropped from the provider itself, not just
        // ignored here: the completion path reads the provider's selection
        // to capture the descriptor the import service records.
        expect(_selectedDevice(tester), isNull);

        h.service.onDeviceDiscovered(_advert(_savedAddress));
        await _settle(tester);

        expect(h.hostApi.downloads.single.address, _savedAddress);
        expect(_selectedDevice(tester)?.address, _savedAddress);
      },
    );

    testWidgets(
      'drops a stale Bluetooth selection for a USB computer without scanning',
      (tester) async {
        final h = _Harness(
          seed: DiscoveryState(
            selectedDevice: _discovered('11:22:33:44:55:66'),
          ),
        );
        await tester.pumpWidget(
          h.build(
            _savedComputer(
              connectionType: 'usb',
              bluetoothAddress: '/dev/ttyUSB0',
            ),
          ),
        );
        await _settle(tester);

        expect(h.hostApi.calls, ['startDownload']);
        expect(h.hostApi.downloads.single.address, '/dev/ttyUSB0');
        expect(_selectedDevice(tester), isNull);
      },
    );

    testWidgets('does not scan for a USB computer', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(
        h.build(
          _savedComputer(
            connectionType: 'usb',
            bluetoothAddress: '/dev/ttyUSB0',
          ),
        ),
      );
      await _settle(tester);

      expect(h.hostApi.calls, ['startDownload']);
      expect(h.hostApi.downloads.single.address, '/dev/ttyUSB0');
    });
  });
}
