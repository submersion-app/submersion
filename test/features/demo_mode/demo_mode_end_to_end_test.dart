import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/demo_mode/data/demo_database_preparer.dart';
import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/data/demo_manifest_client.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_service.dart';
import 'package:submersion/features/demo_mode/data/demo_package_extractor.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/data/demo_state_store.dart';

import '../../../tool/demo_data/src/packaging/demo_builder.dart';
import '../../helpers/global_test_defaults.dart';
import '../../tool/demo_data/seed_harness.dart';
import '../../tool/demo_data/synthetic_shapes.dart';
import 'data/demo_mode_test_support.dart';

/// Demo mode from the published files to an exit (issue #3708): a package
/// the release tooling builds, served over HTTP, downloaded, checked,
/// unpacked, prepared and opened, then left with the user's logbook and
/// settings exactly as they were.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late String manifestJson;
  late List<int> packageBytes;
  late Uri packageUrl;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('demo_e2e');
    final photos = p.join(root.path, 'photos');
    for (final photo in testPhotos) {
      File(p.join(photos, photo.fileName))
        ..createSync(recursive: true)
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    }
    final out = await DemoBuilder().build(
      shapes: syntheticShapes(),
      photosDir: photos,
      photos: testPhotos,
      seed: 7,
      anchor: DateTime(2026, 6, 1),
      outDir: p.join(root.path, 'out'),
    );
    packageBytes = out.zip.readAsBytesSync();
    packageUrl = out.package.url;
    manifestJson = DemoBuilder.mergeManifest(
      entry: File(
        p.join(root.path, 'out', 'manifest-entry.json'),
      ).readAsStringSync(),
    );
  });

  tearDownAll(() {
    DatabaseService.instance.resetForTesting();
    root.deleteSync(recursive: true);
  });

  late DemoPaths paths;
  late String realPath;
  late SharedPreferences prefs;
  late FakeSwitcher switcher;

  setUp(() async {
    final home = Directory(p.join(root.path, 'home'))..createSync();
    paths = DemoPaths(p.join(home.path, 'support'));
    realPath = p.join(home.path, 'Documents', 'submersion.db');
    await writeDatabaseWithDiver(realPath, 'real-diver');
    SharedPreferences.setMockInitialValues({
      'current_diver_id': 'real-diver',
      'sync_auto_enabled': true,
    });
    prefs = await SharedPreferences.getInstance();
    switcher = FakeSwitcher();
    await switcher.openAt(realPath, keyHex: null);
  });

  tearDown(() async {
    applyGlobalTestDefaults();
    await switcher.close();
    Directory(p.join(root.path, 'home')).deleteSync(recursive: true);
  });

  final now = DateTime(2026, 10, 26, 12);

  DemoModeService service() {
    final client = MockClient((request) async {
      if (request.url == Uri.parse(kDemoManifestUrl)) {
        return http.Response(manifestJson, 200);
      }
      if (request.url == packageUrl) {
        return http.Response.bytes(packageBytes, 200);
      }
      return http.Response('not found', 404);
    });
    return DemoModeService(
      paths: paths,
      prefs: prefs,
      store: DemoStateStore(paths),
      manifest: DemoManifestClient(client: client),
      downloader: DemoDownloader(client: client),
      extractor: DemoPackageExtractor(),
      preparer: DemoDatabasePreparer(),
      switcher: switcher,
      realDatabasePath: () async => realPath,
      realKeyHex: () => null,
      deviceId: () => 'device-1',
      cancelDeviceNotifications: () async {},
      restart: () {},
      clock: () => now,
    );
  }

  test('entering opens the sample logbook as the demo diver', () async {
    await service().enter(fromFirstRun: false);

    expect(switcher.openPath, paths.databaseFile);
    expect(DemoModeGate.instance.isActive, isTrue);
    expect(prefs.getString('current_diver_id'), 'demo-diver');
    final diver = await switcher.current
        .customSelect("SELECT name FROM divers WHERE id = 'demo-diver'")
        .getSingle();
    expect(diver.read<String>('name'), isNotEmpty);
    // The logbook was built months ago; its latest dive now sits last week.
    final latest = await switcher.current
        .customSelect('SELECT max(dive_date_time) AS t FROM dives')
        .getSingle();
    final age = now.difference(
      DateTime.fromMillisecondsSinceEpoch(latest.read<int>('t')),
    );
    expect(age.inDays, inInclusiveRange(7, 13));
    final photo = await switcher.current
        .customSelect('SELECT local_path FROM media LIMIT 1')
        .getSingle();
    expect(File(photo.read<String>('local_path')).existsSync(), isTrue);
  });

  test(
    'exiting returns the logbook, the diver and sync as they were',
    () async {
      final before = File(realPath).readAsBytesSync();

      await service().enter(fromFirstRun: false);
      await service().exit();

      expect(switcher.openPath, realPath);
      expect(DemoModeGate.instance.isActive, isFalse);
      expect(prefs.getString('current_diver_id'), 'real-diver');
      expect(prefs.getBool('sync_auto_enabled'), isTrue);
      expect(Directory(paths.root).existsSync(), isFalse);
      await switcher.close();
      expect(File(realPath).readAsBytesSync(), before);
    },
  );
}
