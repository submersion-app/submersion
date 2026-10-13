import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/compaction/database_compaction_prefs.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../helpers/fake_path_provider.dart';

class _FakeLocation implements DatabaseLocationService {
  _FakeLocation(this.path);
  final String path;

  @override
  Future<String> getDatabasePath() async => path;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

class _BrokenPrefs extends DatabaseCompactionPrefs {
  _BrokenPrefs(super.prefs);

  @override
  bool get isRequested => true;

  @override
  Future<void> cancel() => throw StateError('prefs unavailable');
}

/// A compaction requested while the app ran happens at the next launch,
/// before the background connection opens the file (issue #3333).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;
  late DatabaseCompactionPrefs prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('compaction-test');
    dbPath = p.join(tempDir.path, 'submersion.db');
    useFakePathProvider(_FakePathProvider(tempDir.path));
    DatabaseService.instance.resetForTesting();
    SharedPreferences.setMockInitialValues({});
    prefs = DatabaseCompactionPrefs(await SharedPreferences.getInstance());
    // A current-schema file with 20 MB of free pages.
    final seed = AppDatabase(NativeDatabase(File(dbPath)));
    await seed.customSelect('SELECT 1').get();
    await seed.close();
    final raw = sqlite3.sqlite3.open(dbPath);
    try {
      raw.execute('CREATE TABLE junk (b BLOB)');
      final blob = Uint8List(1024 * 1024);
      for (var i = 0; i < 20; i++) {
        raw.execute('INSERT INTO junk VALUES (?)', [blob]);
      }
      raw.execute('DROP TABLE junk');
    } finally {
      raw.close();
    }
  });

  tearDown(() async {
    try {
      await DatabaseService.instance.close(strict: true);
    } finally {
      DatabaseService.instance.resetForTesting();
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> open({void Function()? onCompacting, bool withPrefs = true}) =>
      DatabaseService.instance.initialize(
        locationService: _FakeLocation(dbPath),
        compaction: withPrefs ? prefs : null,
        onCompacting: onCompacting,
      );

  int fileBytes() => File(dbPath).lengthSync();

  test(
    'a requested compaction shrinks the file and clears the request',
    () async {
      await prefs.request();
      final before = fileBytes();
      var told = false;
      await open(onCompacting: () => told = true);
      await DatabaseService.instance.close(strict: true);
      expect(told, isTrue);
      expect(prefs.isRequested, isFalse);
      expect(fileBytes(), lessThan(before - 15 * 1024 * 1024));
    },
  );

  test('nothing is compacted without a request', () async {
    final before = fileBytes();
    var told = false;
    await open(onCompacting: () => told = true);
    await DatabaseService.instance.close(strict: true);
    expect(told, isFalse);
    expect(fileBytes(), greaterThanOrEqualTo(before));
  });

  test('a caller that passes no prefs never compacts', () async {
    await prefs.request();
    final before = fileBytes();
    await open(withPrefs: false);
    await DatabaseService.instance.close(strict: true);
    expect(prefs.isRequested, isTrue);
    expect(fileBytes(), greaterThanOrEqualTo(before));
  });

  test('a preferences failure never stops the database opening', () async {
    await prefs.request();
    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(dbPath),
      compaction: _BrokenPrefs(await SharedPreferences.getInstance()),
    );
    expect(() => DatabaseService.instance.database, returnsNormally);
  });

  test('a failure records the backoff and the database still opens', () async {
    await prefs.request();
    DatabaseService.instance.compactFileOverride = (_, {keyHex}) async =>
        throw StateError('busy');
    addTearDown(() => DatabaseService.instance.compactFileOverride = null);
    await open();
    expect(() => DatabaseService.instance.database, returnsNormally);
    expect(prefs.isRequested, isFalse);
    expect(prefs.inBackoff, isTrue);
  });
}
