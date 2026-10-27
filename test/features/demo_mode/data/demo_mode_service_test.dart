import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' show GeneratedDatabase;
import 'package:submersion/features/demo_mode/data/demo_database_preparer.dart';
import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/data/demo_manifest_client.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_service.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/data/demo_state_store.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';
import 'package:submersion/features/demo_mode/domain/demo_state.dart';

import '../../../helpers/global_test_defaults.dart';
import 'demo_mode_test_support.dart';

void main() {
  late Directory root;
  late DemoPaths paths;
  late DemoStateStore store;
  late String realPath;
  late SharedPreferences prefs;
  late FakeSwitcher switcher;
  late int restarts;
  late int notificationCancels;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('demo_service');
    paths = DemoPaths(p.join(root.path, 'support'));
    store = DemoStateStore(paths);
    realPath = p.join(root.path, 'Documents', 'submersion.db');
    await writeDatabaseWithDiver(realPath, 'real-diver');
    SharedPreferences.setMockInitialValues({
      'current_diver_id': 'real-diver',
      'sync_auto_enabled': true,
      'db_storage_mode': 'customFolder',
      'db_custom_path': '/x',
      'db_encryption_enabled': true,
    });
    prefs = await SharedPreferences.getInstance();
    switcher = FakeSwitcher();
    await switcher.openAt(realPath, keyHex: 'k' * 64);
    restarts = 0;
    notificationCancels = 0;
  });

  tearDown(() async {
    applyGlobalTestDefaults();
    await switcher.close();
    root.deleteSync(recursive: true);
  });

  DemoModeService service({
    FakeDownloader? downloader,
    FakeSwitcher? sw,
    bool hasPackage = true,
    DemoManifestClient? manifest,
  }) => DemoModeService(
    paths: paths,
    prefs: prefs,
    store: store,
    manifest: manifest ?? FakeManifestClient(hasPackage ? testPackage : null),
    downloader: downloader ?? FakeDownloader(),
    extractor: FakeExtractor(),
    preparer: DemoDatabasePreparer(),
    switcher: sw ?? switcher,
    realDatabasePath: () async => realPath,
    realKeyHex: () => 'k' * 64,
    deviceId: () => 'device-1',
    cancelDeviceNotifications: () async => notificationCancels++,
    restart: () => restarts++,
    clock: () => DateTime(2026, 10, 26, 12),
  );

  test(
    'enter switches to the demo database, snapshots prefs and restarts once',
    () async {
      await service().enter(fromFirstRun: false, package: testPackage);

      expect(switcher.openPath, paths.databaseFile);
      expect(prefs.getString('current_diver_id'), 'demo-diver');
      expect(File(paths.prefsSnapshotFile).existsSync(), isTrue);
      expect((await store.read())!.phase, DemoPhase.active);
      expect(DemoModeGate.instance.isActive, isTrue);
      expect(restarts, 1);
      expect(notificationCancels, 1);
    },
  );

  test('enter reads the manifest again and downloads its current entry when '
      'the size is unchanged', () async {
    // A rebuild republished at the same size: new URL and checksum, so the
    // package the user agreed to would fail the download.
    final republished = DemoPackage(
      schemaVersion: testPackage.schemaVersion,
      url: Uri.parse('https://example.com/republished.zip'),
      sha256: 'b' * 64,
      size: testPackage.size,
      generatedAt: DateTime.utc(2026, 10, 21),
    );
    final manifest = _CountingManifest(republished);
    final downloader = _RecordingDownloader();

    await service(
      manifest: manifest,
      downloader: downloader,
    ).enter(fromFirstRun: false, package: testPackage);

    expect(manifest.calls, 1);
    expect(downloader.downloaded, [republished]);
  });

  test('enter downloads nothing and names the new package when its size '
      'changed', () async {
    final bigger = DemoPackage(
      schemaVersion: testPackage.schemaVersion,
      url: Uri.parse('https://example.com/bigger.zip'),
      sha256: 'c' * 64,
      size: testPackage.size * 4,
      generatedAt: DateTime.utc(2026, 10, 22),
    );
    final downloader = _RecordingDownloader();

    await expectLater(
      service(
        manifest: _CountingManifest(bigger),
        downloader: downloader,
      ).enter(fromFirstRun: false, package: testPackage),
      throwsA(
        isA<DemoPackageChangedException>().having(
          (e) => e.current,
          'current',
          bigger,
        ),
      ),
    );

    expect(downloader.downloaded, isEmpty);
    expect(Directory(paths.root).existsSync(), isFalse);
    expect(switcher.openPath, realPath);
    expect(restarts, 0);
  });

  test('enter tries the agreed package when the manifest cannot be '
      'reached', () async {
    final downloader = _RecordingDownloader();

    await service(
      hasPackage: false,
      downloader: downloader,
    ).enter(fromFirstRun: false, package: testPackage);

    expect(downloader.downloaded, [testPackage]);
    expect(switcher.openPath, paths.databaseFile);
  });

  test('enter reports downloading, preparing and opening in order', () async {
    final stages = <DemoEnterStage>[];

    await service().enter(
      fromFirstRun: false,
      package: testPackage,
      onProgress: (p) {
        if (stages.isEmpty || stages.last != p.stage) stages.add(p.stage);
      },
    );

    expect(stages, [
      DemoEnterStage.downloading,
      DemoEnterStage.preparing,
      DemoEnterStage.opening,
    ]);
  });

  test(
    'enter failing during download leaves no demo directory and the gate inactive',
    () async {
      await expectLater(
        service(
          downloader: FakeDownloader(failWith: DemoDownloadFailure.network),
        ).enter(fromFirstRun: false, package: testPackage),
        throwsA(isA<DemoDownloadException>()),
      );

      expect(Directory(paths.root).existsSync(), isFalse);
      expect(DemoModeGate.instance.isActive, isFalse);
      expect(switcher.openPath, realPath);
      expect(restarts, 0);
    },
  );

  test(
    'a cancel that lands as the download finishes still ends the entry',
    () async {
      var cancelled = false;

      await expectLater(
        service(downloader: _CancelOnLastChunk(() => cancelled = true)).enter(
          fromFirstRun: false,
          package: testPackage,
          isCancelled: () => cancelled,
        ),
        throwsA(
          isA<DemoDownloadException>().having(
            (e) => e.reason,
            'reason',
            DemoDownloadFailure.cancelled,
          ),
        ),
      );
      expect(Directory(paths.root).existsSync(), isFalse);
      expect(DemoModeGate.instance.isActive, isFalse);
      expect(restarts, 0);
    },
  );

  test(
    'enter failing after the commit point reopens the real database and restores prefs',
    () async {
      final failing = FakeSwitcher(failOpenOf: paths.databaseFile);
      await failing.openAt(realPath, keyHex: 'k' * 64);
      addTearDown(failing.close);

      await expectLater(
        service(sw: failing).enter(fromFirstRun: false, package: testPackage),
        throwsA(isA<StateError>()),
      );

      expect(failing.openPath, realPath);
      expect(prefs.getString('current_diver_id'), 'real-diver');
      expect(Directory(paths.root).existsSync(), isFalse);
      expect(DemoModeGate.instance.isActive, isFalse);
      // The real logbook is a new database instance; the app scope must be
      // rebuilt or every provider keeps the closed one.
      expect(restarts, 1);
    },
  );

  test(
    'the state on disk stays entering until the sample logbook is prepared',
    () async {
      final phases = <DemoPhase?>[];
      final gate = <bool>[];
      final recording = _RecordingPreparer(() async {
        phases.add((await store.read())?.phase);
        gate.add(DemoModeGate.instance.isActive);
      });

      await DemoModeService(
        paths: paths,
        prefs: prefs,
        store: store,
        manifest: FakeManifestClient(testPackage),
        downloader: FakeDownloader(),
        extractor: FakeExtractor(),
        preparer: recording,
        switcher: switcher,
        realDatabasePath: () async => realPath,
        realKeyHex: () => 'k' * 64,
        deviceId: () => 'device-1',
        cancelDeviceNotifications: () async {},
        restart: () => restarts++,
      ).enter(fromFirstRun: false, package: testPackage);

      // A kill while preparing relaunches as entering, which cleans up,
      // rather than as active over a half-prepared logbook.
      expect(phases, [DemoPhase.entering]);
      // Sealed features already refuse while the switch is under way.
      expect(gate, [isTrue]);
      expect((await store.read())!.phase, DemoPhase.active);
    },
  );

  test('exit with an unreadable preferences snapshot still finishes', () async {
    await service().enter(fromFirstRun: false, package: testPackage);
    File(paths.prefsSnapshotFile).writeAsStringSync('not a snapshot');

    await service().exit();

    expect(switcher.openPath, realPath);
    expect(Directory(paths.root).existsSync(), isFalse);
    expect(DemoModeGate.instance.isActive, isFalse);
    expect(restarts, 2);
  });

  test(
    'exit when the real logbook cannot reopen leaves exiting for startup and restarts',
    () async {
      await service().enter(fromFirstRun: false, package: testPackage);
      final failing = FakeSwitcher(failOpenOf: realPath);
      await failing.openAt(paths.databaseFile, keyHex: null);
      addTearDown(failing.close);

      await service(sw: failing).exit();

      // Startup finishes the exit on the restart and shows its own screens
      // for a logbook it cannot open.
      expect((await store.read())!.phase, DemoPhase.exiting);
      expect(restarts, 2);
    },
  );

  test(
    'enter never applies the real encryption key to the demo file; exit restores it',
    () async {
      await service().enter(fromFirstRun: false, package: testPackage);
      expect(switcher.keys.last, isNull);

      await service().exit();
      expect(switcher.keys.last, 'k' * 64);
      expect(switcher.openPath, realPath);
    },
  );

  test(
    'exit restores current_diver_id, sync and storage prefs exactly',
    () async {
      await service().enter(fromFirstRun: false, package: testPackage);
      await prefs.setBool('sync_auto_enabled', false);
      await prefs.setString('demo_only', 'x');

      await service().exit();

      expect(prefs.getString('current_diver_id'), 'real-diver');
      expect(prefs.getBool('sync_auto_enabled'), isTrue);
      expect(prefs.getString('db_storage_mode'), 'customFolder');
      expect(prefs.getString('db_custom_path'), '/x');
      expect(prefs.getBool('db_encryption_enabled'), isTrue);
      expect(prefs.containsKey('demo_only'), isFalse);
    },
  );

  test('exit finds the real logbook from the restored preferences', () async {
    // The real path is read from the storage preferences, as production's
    // DatabaseLocationService does.
    final svc = DemoModeService(
      paths: paths,
      prefs: prefs,
      store: store,
      manifest: FakeManifestClient(testPackage),
      downloader: FakeDownloader(),
      extractor: FakeExtractor(),
      preparer: DemoDatabasePreparer(),
      switcher: switcher,
      realDatabasePath: () async => prefs.getString('db_custom_path') == '/x'
          ? realPath
          : p.join(root.path, 'elsewhere.db'),
      realKeyHex: () => 'k' * 64,
      deviceId: () => null,
      cancelDeviceNotifications: () async {},
      restart: () => restarts++,
    );
    await svc.enter(fromFirstRun: false, package: testPackage);
    await prefs.setString('db_custom_path', '/moved-during-demo');

    await svc.exit();

    expect(switcher.openPath, realPath);
    expect(File(p.join(root.path, 'elsewhere.db')).existsSync(), isFalse);
  });

  test('exit forgets the cached thumbnails of the sample photos', () async {
    final forgotten = <String>[];
    final svc = DemoModeService(
      paths: paths,
      prefs: prefs,
      store: store,
      manifest: FakeManifestClient(testPackage),
      downloader: FakeDownloader(),
      extractor: FakeExtractor(),
      preparer: DemoDatabasePreparer(),
      switcher: switcher,
      realDatabasePath: () async => realPath,
      realKeyHex: () => 'k' * 64,
      deviceId: () => null,
      cancelDeviceNotifications: () async {},
      restart: () => restarts++,
      forgetPhotos: (photoPaths) async => forgotten.addAll(photoPaths),
    );
    await svc.enter(fromFirstRun: false, package: testPackage);

    await svc.exit();

    expect(forgotten, [p.join(paths.photosDir, 'reef.jpg')]);
    expect(Directory(paths.root).existsSync(), isFalse);
  });

  test('exit deletes the demo database, package, photos and state', () async {
    await service().enter(fromFirstRun: false, package: testPackage);

    await service().exit();

    expect(Directory(paths.root).existsSync(), isFalse);
    expect(await store.read(), isNull);
    expect(DemoModeGate.instance.isActive, isFalse);
    expect(restarts, 2);
    expect(notificationCancels, 2);
  });

  test('the real database is untouched by a full enter and exit', () async {
    final before = File(realPath).readAsBytesSync();

    await service().enter(fromFirstRun: false, package: testPackage);
    await service().exit();
    await switcher.close();

    expect(File(realPath).readAsBytesSync(), before);
  });
}

/// Runs [onPrepare] when the service prepares the sample logbook, then
/// prepares it as usual.
class _RecordingPreparer extends DemoDatabasePreparer {
  _RecordingPreparer(this.onPrepare);

  final Future<void> Function() onPrepare;

  @override
  Future<void> prepare(
    GeneratedDatabase db, {
    required DateTime now,
    required String photosDir,
    required String? deviceId,
    DemoUnitSettings? units,
  }) async {
    await onPrepare();
    return super.prepare(
      db,
      now: now,
      photosDir: photosDir,
      deviceId: deviceId,
      units: units,
    );
  }
}

/// Completes the download, but the user's Cancel lands with the last chunk.
class _CancelOnLastChunk extends FakeDownloader {
  _CancelOnLastChunk(this.cancel);

  final void Function() cancel;

  @override
  Future<File> download(
    DemoPackage pkg,
    File dest, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final file = await super.download(pkg, dest, onProgress: onProgress);
    cancel();
    return file;
  }
}

class _CountingManifest extends FakeManifestClient {
  _CountingManifest(super.package);

  int calls = 0;

  @override
  Future<DemoPackage?> fetchBest(int appSchemaVersion) {
    calls++;
    return super.fetchBest(appSchemaVersion);
  }
}

/// Records which package each download was asked for.
class _RecordingDownloader extends FakeDownloader {
  final downloaded = <DemoPackage>[];

  @override
  Future<File> download(
    DemoPackage pkg,
    File dest, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) {
    downloaded.add(pkg);
    return super.download(
      pkg,
      dest,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }
}
