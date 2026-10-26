import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/demo_mode/data/demo_database_preparer.dart';
import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_service.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/data/demo_state_store.dart';
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
  }) => DemoModeService(
    paths: paths,
    prefs: prefs,
    store: store,
    manifest: FakeManifestClient(hasPackage ? testPackage : null),
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
      await service().enter(fromFirstRun: false);

      expect(switcher.openPath, paths.databaseFile);
      expect(prefs.getString('current_diver_id'), 'demo-diver');
      expect(File(paths.prefsSnapshotFile).existsSync(), isTrue);
      expect((await store.read())!.phase, DemoPhase.active);
      expect(DemoModeGate.instance.isActive, isTrue);
      expect(restarts, 1);
      expect(notificationCancels, 1);
    },
  );

  test('enter reports downloading, preparing and opening in order', () async {
    final stages = <DemoEnterStage>[];

    await service().enter(
      fromFirstRun: false,
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
        ).enter(fromFirstRun: false),
        throwsA(isA<DemoDownloadException>()),
      );

      expect(Directory(paths.root).existsSync(), isFalse);
      expect(DemoModeGate.instance.isActive, isFalse);
      expect(switcher.openPath, realPath);
      expect(restarts, 0);
    },
  );

  test('enter with no compatible package fails as a network failure', () async {
    await expectLater(
      service(hasPackage: false).enter(fromFirstRun: false),
      throwsA(
        isA<DemoDownloadException>().having(
          (e) => e.reason,
          'reason',
          DemoDownloadFailure.network,
        ),
      ),
    );
    expect(Directory(paths.root).existsSync(), isFalse);
  });

  test(
    'enter failing after the commit point reopens the real database and restores prefs',
    () async {
      final failing = FakeSwitcher(failOpenOf: paths.databaseFile);
      await failing.openAt(realPath, keyHex: 'k' * 64);
      addTearDown(failing.close);

      await expectLater(
        service(sw: failing).enter(fromFirstRun: false),
        throwsA(isA<StateError>()),
      );

      expect(failing.openPath, realPath);
      expect(prefs.getString('current_diver_id'), 'real-diver');
      expect(Directory(paths.root).existsSync(), isFalse);
      expect(DemoModeGate.instance.isActive, isFalse);
    },
  );

  test(
    'enter never applies the real encryption key to the demo file; exit restores it',
    () async {
      await service().enter(fromFirstRun: false);
      expect(switcher.keys.last, isNull);

      await service().exit();
      expect(switcher.keys.last, 'k' * 64);
      expect(switcher.openPath, realPath);
    },
  );

  test(
    'exit restores current_diver_id, sync and storage prefs exactly',
    () async {
      await service().enter(fromFirstRun: false);
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

  test('exit deletes the demo database, package, photos and state', () async {
    await service().enter(fromFirstRun: false);

    await service().exit();

    expect(Directory(paths.root).existsSync(), isFalse);
    expect(await store.read(), isNull);
    expect(DemoModeGate.instance.isActive, isFalse);
    expect(restarts, 2);
    expect(notificationCancels, 2);
  });

  test('the real database is untouched by a full enter and exit', () async {
    final before = File(realPath).readAsBytesSync();

    await service().enter(fromFirstRun: false);
    await service().exit();
    await switcher.close();

    expect(File(realPath).readAsBytesSync(), before);
  });
}
