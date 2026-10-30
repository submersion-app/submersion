import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';

class _PinnedLocationService extends DatabaseLocationService {
  _PinnedLocationService(super.prefs, this.path);

  final String path;

  @override
  Future<String> getDatabasePath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('db-path-override-');
    DatabaseService.instance.resetForTesting();
  });

  tearDown(() async {
    try {
      await DatabaseService.instance.close(strict: true);
    } finally {
      DatabaseService.instance.resetForTesting();
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'initialize opens pathOverride instead of the location service path',
    () async {
      final real = p.join(tempDir.path, 'real', 'submersion.db');
      final demo = p.join(tempDir.path, 'demo_mode', 'submersion_demo.db');

      await DatabaseService.instance.initialize(
        locationService: _PinnedLocationService(prefs, real),
        pathOverride: demo,
      );

      expect(DatabaseService.instance.currentPath, demo);
      expect(File(demo).existsSync(), isTrue);
      expect(File(real).existsSync(), isFalse);
    },
  );
}
