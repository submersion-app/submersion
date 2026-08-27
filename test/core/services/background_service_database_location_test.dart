import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/background_service.dart';
import 'package:submersion/core/services/database_service.dart';

/// Routes getApplicationDocumentsDirectory into the test sandbox so the
/// default-path fallback resolves somewhere real and distinguishable from the
/// custom folder.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String customFolder;
  late String defaultFolder;
  late String defaultDbPath;
  late PathProviderPlatform originalPathProvider;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('headless-db-location-');
    customFolder = p.join(tempDir.path, 'elsewhere');
    Directory(customFolder).createSync(recursive: true);
    defaultFolder = p.join(tempDir.path, 'Submersion');
    defaultDbPath = p.join(defaultFolder, 'submersion.db');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    DatabaseService.instance.resetForTesting();
  });

  tearDown(() {
    // The fake points into a temp dir this tearDown is about to delete, so it
    // must not outlive the test that installed it.
    PathProviderPlatform.instance = originalPathProvider;
    DatabaseService.instance.resetForTesting();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  /// Puts a file where the database belongs.
  ///
  /// The bytes are deliberately arbitrary. The gate's probe asks only whether
  /// this isolate can OPEN the path, never what the file contains: deciding
  /// that a database is valid is the job of the open that follows, and a
  /// header check here would reject an encrypted database, which is
  /// SQLCipher ciphertext from byte zero.
  String seedDatabase(String folder) {
    final path = p.join(folder, 'submersion.db');
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(64, 0));
    return path;
  }

  group('prepareHeadlessDatabaseLocation', () {
    test(
      'points the service at the custom folder, not the default path',
      () async {
        final customDb = seedDatabase(customFolder);
        // A database also sits at the default path, so resolving the custom one
        // cannot be an accident of the default being absent.
        seedDatabase(defaultFolder);
        final prefs = await prefsWith({
          'db_storage_mode': 'customFolder',
          'db_custom_path': customFolder,
        });

        expect(await prepareHeadlessDatabaseLocation(prefs: prefs), isTrue);
        expect(await DatabaseService.instance.databasePath, customDb);
        expect(
          await DatabaseService.instance.databasePath,
          isNot(defaultDbPath),
        );
      },
    );

    test(
      'resolves the default path when no custom location is configured',
      () async {
        seedDatabase(defaultFolder);
        final prefs = await prefsWith({});

        expect(await prepareHeadlessDatabaseLocation(prefs: prefs), isTrue);
        expect(await DatabaseService.instance.databasePath, defaultDbPath);
      },
    );

    test('skips when the custom location holds no database yet', () async {
      final prefs = await prefsWith({
        'db_storage_mode': 'customFolder',
        'db_custom_path': customFolder,
      });

      expect(await prepareHeadlessDatabaseLocation(prefs: prefs), isFalse);
      expect(File(p.join(customFolder, 'submersion.db')).existsSync(), isFalse);
    });

    test(
      'skips without creating a phantom database at the default path',
      () async {
        // The reported failure mode: a custom location the headless isolate
        // cannot see, and a background run that materializes an empty database
        // at the default path as a side effect.
        final prefs = await prefsWith({
          'db_storage_mode': 'customFolder',
          'db_custom_path': p.join(tempDir.path, 'unreachable'),
        });

        expect(await prepareHeadlessDatabaseLocation(prefs: prefs), isFalse);
        expect(File(defaultDbPath).existsSync(), isFalse);
        expect(Directory(defaultFolder).existsSync(), isFalse);
      },
    );

    test(
      'skips when the resolved database cannot be opened for reading',
      () async {
        // A directory at the database path stands in for an unreadable file
        // (a revoked security-scoped bookmark, a detached volume).
        Directory(p.join(customFolder, 'submersion.db')).createSync();
        final prefs = await prefsWith({
          'db_storage_mode': 'customFolder',
          'db_custom_path': customFolder,
        });

        expect(await prepareHeadlessDatabaseLocation(prefs: prefs), isFalse);
      },
    );

    test('never resets a custom location it cannot reach', () async {
      // Resetting is the foreground's answer on bookmark platforms
      // (validateCustomLocationAtStartup). A headless run must not silently
      // rewrite the diver's storage setting from the background.
      final prefs = await prefsWith({
        'db_storage_mode': 'customFolder',
        'db_custom_path': customFolder,
      });

      expect(await prepareHeadlessDatabaseLocation(prefs: prefs), isFalse);
      expect(prefs.getString('db_storage_mode'), 'customFolder');
      expect(prefs.getString('db_custom_path'), customFolder);
    });
  });
}
