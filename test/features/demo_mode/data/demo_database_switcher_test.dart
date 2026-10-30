import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/demo_mode/data/demo_database_switcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late String real;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('demo_switcher');
    real = p.join(dir.path, 'real', 'submersion.db');
    DatabaseService.instance.resetForTesting();
    await DatabaseService.instance.initialize(pathOverride: real);
  });

  tearDown(() async {
    try {
      await DatabaseService.instance.close(strict: true);
    } finally {
      DatabaseService.instance.resetForTesting();
      dir.deleteSync(recursive: true);
    }
  });

  test('openAt closes the open logbook and opens the other one', () async {
    final demo = p.join(dir.path, 'demo_mode', 'submersion_demo.db');
    const switcher = DatabaseServiceDemoSwitcher();

    await switcher.openAt(demo, keyHex: null);

    expect(DatabaseService.instance.currentPath, demo);
    expect(DatabaseService.instance.databaseKeyHex, isNull);
    expect(
      identical(switcher.current, DatabaseService.instance.database),
      isTrue,
    );
    expect(await switcher.current.customSelect('SELECT 1').get(), hasLength(1));
  });

  test('a file that will not open leaves the previous key in place', () async {
    final broken = File(p.join(dir.path, 'broken.db'))
      ..writeAsStringSync('not a database, just text');
    DatabaseService.instance.databaseKeyHex = 'previous-key';

    await expectLater(
      const DatabaseServiceDemoSwitcher().openAt(broken.path, keyHex: null),
      throwsA(anything),
    );

    expect(DatabaseService.instance.databaseKeyHex, 'previous-key');
  });
}
