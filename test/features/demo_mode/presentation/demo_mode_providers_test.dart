import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/demo_mode/data/demo_database_preparer.dart';
import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/data/demo_manifest_client.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_service.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/data/demo_state_store.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_job_provider.dart';
import 'package:submersion/features/media/data/services/local_thumbnail_cache.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/global_test_defaults.dart';
import '../../../helpers/mock_channels.dart';
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

/// Offers [offered], which a test changes to stand for a republish.
class _RepublishingClient extends FakeManifestClient {
  _RepublishingClient(this.offered);

  DemoPackage offered;

  @override
  Future<DemoPackage?> fetchBest(int appSchemaVersion) async => offered;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      DemoDownloader downloader, {
      String? failOpenOf,
      DemoManifestClient? manifest,
      bool importRunning = false,
    }) async {
      final client = manifest ?? FakeManifestClient(testPackage);
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
        manifest: client,
        downloader: downloader,
        extractor: FakeExtractor(),
        preparer: DemoDatabasePreparer(),
        switcher: switcher,
        realDatabasePath: () async => realPath,
        realKeyHex: () => null,
        deviceId: () => null,
        cancelDeviceNotifications: () async {},
        restart: () {},
        importRunning: () => importRunning,
      );
      final container = ProviderContainer(
        overrides: [
          demoModeServiceProvider.overrideWith((ref) => service),
          demoManifestClientProvider.overrideWithValue(client),
        ],
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
          .start(fromFirstRun: false, package: testPackage);

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
            .start(fromFirstRun: false, package: testPackage);

        expect(
          container.read(demoEnterControllerProvider),
          isA<DemoEnterFailed>(),
        );
      },
    );

    test('a cancelled entry stays cancelled when entry starts again', () async {
      final downloader = _HeldDownloader();
      final container = await containerWith(downloader);
      final controller = container.read(demoEnterControllerProvider.notifier);

      // Cancel while the first download waits for its next chunk, then start
      // again at once, as a quick second tap on the entry would.
      final first = controller.start(fromFirstRun: false, package: testPackage);
      await pumpEventQueue();
      controller
        ..cancel()
        ..reset();
      final second = controller.start(
        fromFirstRun: false,
        package: testPackage,
      );
      downloader.release.complete();
      await Future.wait([first, second]);

      expect(downloader.cancelled, 1);
      expect(downloader.completed, 1);
      expect(
        container.read(demoEnterControllerProvider),
        isA<DemoEnterRunning>(),
      );
    });

    test('a package that changed size asks again and refreshes '
        'availability', () async {
      final bigger = DemoPackage(
        schemaVersion: testPackage.schemaVersion,
        url: Uri.parse('https://example.com/bigger.zip'),
        sha256: 'c' * 64,
        size: testPackage.size * 4,
        generatedAt: DateTime.utc(2026, 10, 22),
      );
      final manifest = _RepublishingClient(testPackage);
      final container = await containerWith(
        FakeDownloader(),
        manifest: manifest,
      );
      // Availability, and so the size the question showed, was read before
      // the republish.
      expect(
        await container.read(demoAvailabilityProvider.future),
        testPackage,
      );
      manifest.offered = bigger;

      await container
          .read(demoEnterControllerProvider.notifier)
          .start(fromFirstRun: false, package: testPackage);

      expect(
        container.read(demoEnterControllerProvider),
        isA<DemoEnterPackageChanged>().having(
          (s) => s.package,
          'package',
          bigger,
        ),
      );
      expect(await container.read(demoAvailabilityProvider.future), bigger);
    });

    test('a running import ends on its own message, not failed', () async {
      final container = await containerWith(
        FakeDownloader(),
        importRunning: true,
      );

      await container
          .read(demoEnterControllerProvider.notifier)
          .start(fromFirstRun: false, package: testPackage);

      expect(
        container.read(demoEnterControllerProvider),
        isA<DemoEnterImportRunning>(),
      );
    });

    test('a successful entry ends running, not failed', () async {
      final container = await containerWith(FakeDownloader());

      await container
          .read(demoEnterControllerProvider.notifier)
          .start(fromFirstRun: true, package: testPackage);

      expect(
        container.read(demoEnterControllerProvider),
        isA<DemoEnterRunning>(),
      );
    });
  });

  group('dives being written', () {
    test('an import job running counts', () {
      expect(divesBeingWritten(importJobRunning: true), isTrue);
    });

    test('a dive computer download counts until its dives are saved', () {
      for (final phase in DownloadPhase.values) {
        expect(
          divesBeingWritten(importJobRunning: false, diveComputerPhase: phase),
          switch (phase) {
            DownloadPhase.connecting ||
            DownloadPhase.pinRequired ||
            DownloadPhase.enumerating ||
            DownloadPhase.downloading ||
            DownloadPhase.processing => isTrue,
            _ => isFalse,
          },
          reason: phase.name,
        );
      }
    });

    test('nothing running, or no download ever started, does not', () {
      expect(divesBeingWritten(importJobRunning: false), isFalse);
    });
  });

  group('production wiring', () {
    late Directory support;

    setUp(() {
      support = Directory.systemTemp.createTempSync('demo_support');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => support.path,
          );
    });
    tearDown(() => support.deleteSync(recursive: true));
    tearDownAll(clearPathAndShareChannelMocks);

    test('the service keeps its files under app support and forgets photo '
        'thumbnails through the cache', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final removed = <String>[];
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localThumbnailCacheProvider.overrideWithValue(
            _RecordingThumbnails(removed),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = await container.read(demoModeServiceProvider.future);
      final photo = p.join(service.paths.photosDir, 'reef.jpg');
      await service.forgetPhotos!([photo]);

      expect(service.paths.root, p.join(support.path, 'demo_mode'));
      expect(removed, [photo]);
    });

    test('the service sees an import the import job is running', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          importJobProvider.overrideWith(_RunningImportJob.new),
        ],
      );
      addTearDown(container.dispose);

      final service = await container.read(demoModeServiceProvider.future);

      expect(service.importRunning!(), isTrue);
    });

    test('the exit action leaves demo mode through the service', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final realPath = p.join(support.path, 'submersion.db');
      await writeDatabaseWithDiver(realPath, 'real');
      final switcher = FakeSwitcher();
      addTearDown(switcher.close);
      var restarts = 0;
      final paths = DemoPaths(support.path);
      final service = DemoModeService(
        paths: paths,
        prefs: prefs,
        store: DemoStateStore(paths),
        manifest: FakeManifestClient(testPackage),
        downloader: FakeDownloader(),
        extractor: FakeExtractor(),
        preparer: DemoDatabasePreparer(),
        switcher: switcher,
        realDatabasePath: () async => realPath,
        realKeyHex: () => null,
        deviceId: () => null,
        cancelDeviceNotifications: () async {},
        restart: () => restarts++,
      );
      final container = ProviderContainer(
        overrides: [demoModeServiceProvider.overrideWith((ref) => service)],
      );
      addTearDown(container.dispose);

      await container.read(demoExitActionProvider)();

      expect(switcher.openPath, realPath);
      expect(restarts, 1);
    });
  });
}

/// Holds every download until [release] completes, then honours a
/// cancellation the way the real downloader does at its next chunk.
class _HeldDownloader extends FakeDownloader {
  final release = Completer<void>();
  int cancelled = 0;
  int completed = 0;

  @override
  Future<File> download(
    DemoPackage pkg,
    File dest, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    await release.future;
    if (isCancelled?.call() ?? false) {
      cancelled++;
      throw const DemoDownloadException(DemoDownloadFailure.cancelled);
    }
    completed++;
    return super.download(pkg, dest, onProgress: onProgress);
  }
}

/// Records the photo paths whose thumbnails are dropped.
class _RecordingThumbnails extends LocalThumbnailCache {
  _RecordingThumbnails(this.removed)
    : super(store: () => throw UnimplementedError('not used'));

  final List<String> removed;

  @override
  Future<void> removePath(String path) async => removed.add(path);
}

class _RunningImportJob extends ImportJobNotifier {
  @override
  ImportJobState build() => const ImportJobState(isRunning: true);
}
