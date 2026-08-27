import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';

/// A location service pinned to a caller-provided path, so a test can tell
/// "resolved through the location service" apart from "fell back to the
/// application documents directory".
class _CustomLocationService extends DatabaseLocationService {
  _CustomLocationService(super.prefs, this.path);

  final String path;

  @override
  Future<String> getDatabasePath() async => path;
}

/// Routes getApplicationDocumentsDirectory into the test sandbox so the
/// default-path fallback resolves to somewhere real and distinguishable.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late Directory tempDir;
  late String customPath;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('db-location-adoption-');
    customPath = p.join(tempDir.path, 'elsewhere', 'dive.db');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    DatabaseService.instance.resetForTesting();
  });

  tearDown(() async {
    try {
      await DatabaseService.instance.close(strict: true);
    } finally {
      DatabaseService.instance.resetForTesting();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    }
  });

  group('DatabaseService.adoptLocationService', () {
    test('registers a location service without opening the database', () async {
      DatabaseService.instance.adoptLocationService(
        _CustomLocationService(prefs, customPath),
      );

      // The startup failure screen relies on this: restore() must target the
      // diver's configured path even on a launch where initialize() never ran.
      expect(await DatabaseService.instance.databasePath, customPath);
      expect(
        DatabaseService.instance.currentPath,
        isNull,
        reason: 'adopting must not imply an open database',
      );
    });

    test('does not displace a service registered earlier', () async {
      final firstPath = p.join(tempDir.path, 'first.db');
      DatabaseService.instance.adoptLocationService(
        _CustomLocationService(prefs, firstPath),
      );
      DatabaseService.instance.adoptLocationService(
        _CustomLocationService(prefs, customPath),
      );

      expect(await DatabaseService.instance.databasePath, firstPath);
    });

    test('resetForTesting clears the registration', () async {
      DatabaseService.instance.adoptLocationService(
        _CustomLocationService(prefs, customPath),
      );
      DatabaseService.instance.resetForTesting();

      expect(await DatabaseService.instance.databasePath, isNot(customPath));
    });
  });

  group('initialize retains an already-registered location service', () {
    test(
      'a bare initialize reopens the custom path, not the default',
      () async {
        await DatabaseService.instance.initialize(
          locationService: _CustomLocationService(prefs, customPath),
        );
        expect(DatabaseService.instance.currentPath, customPath);

        // restore() reopens through a bare initialize(). Before this fix that
        // cleared the location service, so the reopen resolved the application
        // documents directory and silently abandoned the custom location.
        await DatabaseService.instance.close(strict: true);
        await DatabaseService.instance.initialize();

        expect(DatabaseService.instance.currentPath, customPath);
      },
    );
  });
}
