import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/demo_mode/data/demo_database_preparer.dart';
import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_service.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/data/demo_state_store.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/global_test_defaults.dart';
import '../data/demo_mode_test_support.dart';

class _CountingClient extends FakeManifestClient {
  _CountingClient(super.package);

  int calls = 0;

  @override
  Future<DemoPackage?> fetchBest(int appSchemaVersion) async {
    calls++;
    return super.fetchBest(appSchemaVersion);
  }
}

void main() {
  tearDown(applyGlobalTestDefaults);

  group('availability', () {
    test('is null when no sample logbook is reachable', () async {
      final container = ProviderContainer(
        overrides: [
          demoManifestClientProvider.overrideWithValue(FakeManifestClient()),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(demoAvailabilityProvider.future), isNull);
    });

    test('is fetched once for the session', () async {
      final client = _CountingClient(testPackage);
      final container = ProviderContainer(
        overrides: [demoManifestClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(demoAvailabilityProvider.future),
        testPackage,
      );
      await container.read(demoAvailabilityProvider.future);

      expect(client.calls, 1);
    });
  });

  group('units', () {
    test('follow the current settings', () {
      const settings = AppSettings(
        depthUnit: DepthUnit.feet,
        temperatureUnit: TemperatureUnit.fahrenheit,
        themeMode: ThemeMode.dark,
      );

      final units = demoUnitsFromSettings(settings).values;

      expect(units['depth_unit'], 'feet');
      expect(units['temperature_unit'], 'fahrenheit');
      expect(units['theme_mode'], 'dark');
      expect(units.keys, everyElement(isIn(demoUnitSettingColumns)));
    });

    test('follow the locale preset on first run', () {
      expect(
        demoUnitsForPreset(UnitPreset.imperial).values['depth_unit'],
        'feet',
      );
      expect(
        demoUnitsForPreset(UnitPreset.metric).values['pressure_unit'],
        'bar',
      );
    });
  });

  group('entering', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('demo_ctrl'));
    tearDown(() => root.deleteSync(recursive: true));

    Future<ProviderContainer> containerWith(
      FakeDownloader downloader, {
      String? failOpenOf,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final paths = DemoPaths(p.join(root.path, 'support'));
      final realPath = p.join(root.path, 'submersion.db');
      await writeDatabaseWithDiver(realPath, 'real');
      final switcher = FakeSwitcher(
        failOpenOf: failOpenOf == null ? null : paths.databaseFile,
      );
      await switcher.openAt(realPath, keyHex: null);
      addTearDown(switcher.close);
      final service = DemoModeService(
        paths: paths,
        prefs: prefs,
        store: DemoStateStore(paths),
        manifest: FakeManifestClient(testPackage),
        downloader: downloader,
        extractor: FakeExtractor(),
        preparer: DemoDatabasePreparer(),
        switcher: switcher,
        realDatabasePath: () async => realPath,
        realKeyHex: () => null,
        deviceId: () => null,
        cancelDeviceNotifications: () async {},
        restart: () {},
      );
      final container = ProviderContainer(
        overrides: [demoModeServiceProvider.overrideWith((ref) => service)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('moves idle, then running, then failed, and back on retry', () async {
      final container = await containerWith(
        FakeDownloader(failWith: DemoDownloadFailure.network),
      );
      final states = <DemoEnterUiState>[];
      container.listen(
        demoEnterControllerProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );

      await container
          .read(demoEnterControllerProvider.notifier)
          .start(fromFirstRun: false);

      expect(states.first, isA<DemoEnterIdle>());
      expect(states.any((s) => s is DemoEnterRunning), isTrue);
      expect(
        states.last,
        isA<DemoEnterFailed>().having(
          (s) => s.reason,
          'reason',
          DemoDownloadFailure.network,
        ),
      );

      container.read(demoEnterControllerProvider.notifier).reset();
      expect(container.read(demoEnterControllerProvider), isA<DemoEnterIdle>());
    });

    test(
      'an Error after the download ends failed, not stuck running',
      () async {
        // FakeSwitcher throws a StateError (an Error, not an Exception) when
        // it is asked to open the sample logbook.
        final container = await containerWith(
          FakeDownloader(),
          failOpenOf: 'demo',
        );

        await container
            .read(demoEnterControllerProvider.notifier)
            .start(fromFirstRun: false);

        expect(
          container.read(demoEnterControllerProvider),
          isA<DemoEnterFailed>(),
        );
      },
    );

    test('a successful entry ends running, not failed', () async {
      final container = await containerWith(FakeDownloader());

      await container
          .read(demoEnterControllerProvider.notifier)
          .start(fromFirstRun: true);

      expect(
        container.read(demoEnterControllerProvider),
        isA<DemoEnterRunning>(),
      );
    });
  });
}
