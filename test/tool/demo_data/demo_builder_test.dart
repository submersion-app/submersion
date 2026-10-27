import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../../tool/demo_data/src/packaging/demo_builder.dart';
import '../../../tool/demo_data/src/seeders/demo_seeding.dart';
import '../../../tool/demo_data/src/seeders/seed_context.dart';
import 'seed_harness.dart';
import 'synthetic_shapes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('demo_build');
    for (final photo in testPhotos) {
      File(p.join(dir.path, 'photos', photo.fileName))
        ..createSync(recursive: true)
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    }
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
    dir.deleteSync(recursive: true);
  });

  Future<DemoBuildOutput> build({List<Object>? seeders}) => DemoBuilder().build(
    shapes: syntheticShapes(),
    photosDir: p.join(dir.path, 'photos'),
    photos: testPhotos,
    seed: 7,
    anchor: DateTime(2026, 10, 1),
    outDir: p.join(dir.path, 'out'),
    seeders: seeders?.cast(),
  );

  test(
    'a synthetic build produces a zip whose manifest entry matches it',
    () async {
      final out = await build();

      final bytes = out.zip.readAsBytesSync();
      expect(out.package.sha256, sha256.convert(bytes).toString());
      expect(out.package.size, bytes.length);
      expect(out.package.schemaVersion, AppDatabase.currentSchemaVersion);
      expect(out.package.url.toString(), endsWith(p.basename(out.zip.path)));
      final names = ZipDecoder()
          .decodeBytes(bytes)
          .files
          .map((f) => f.name)
          .toSet();
      expect(names, contains('submersion_demo.db'));
      expect(names, containsAll(testPhotos.map((f) => 'photos/${f.fileName}')));
      expect(
        File(p.join(dir.path, 'out', 'manifest-entry.json')).existsSync(),
        isTrue,
      );
    },
  );

  test('no value in the published database names a build folder', () async {
    final out = await build();

    // The database as the zip carries it, opened from a copy.
    final entry = ZipDecoder()
        .decodeBytes(out.zip.readAsBytesSync())
        .files
        .firstWhere((f) => f.name == 'submersion_demo.db');
    final copy = File(p.join(dir.path, 'published.db'))
      ..writeAsBytesSync(entry.content);
    final db = AppDatabase(
      NativeDatabase(copy, setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);

    final paths = await db
        .customSelect('SELECT file_path, local_path FROM media')
        .get();
    expect(paths, isNotEmpty);
    for (final row in paths) {
      // Relative to the package, which the device relinks on entry.
      expect(row.read<String?>('file_path'), startsWith('photos/'));
      expect(row.read<String?>('local_path'), startsWith('photos/'));
    }
  });

  test('each photo is taken during its dive, on the same clock', () async {
    final out = await build();
    final entry = ZipDecoder()
        .decodeBytes(out.zip.readAsBytesSync())
        .files
        .firstWhere((f) => f.name == 'submersion_demo.db');
    final copy = File(p.join(dir.path, 'published.db'))
      ..writeAsBytesSync(entry.content);
    final db = AppDatabase(
      NativeDatabase(copy, setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT m.taken_at - d.dive_date_time AS gap FROM media m '
          'JOIN dives d ON d.id = m.dive_id',
        )
        .get();
    expect(rows, isNotEmpty);
    for (final row in rows) {
      expect(
        row.read<int>('gap'),
        inInclusiveRange(0, const Duration(hours: 1).inMilliseconds),
      );
    }
  });

  test('the build is refused when a value names a build folder', () async {
    await expectLater(
      build(seeders: [...demoSeeders(), _MachinePathSeeder()]),
      throwsA(
        isA<DemoBuildRefused>().having(
          (e) => '$e',
          'message',
          contains('dives.notes'),
        ),
      ),
    );
    expect(Directory(p.join(dir.path, 'out')).existsSync(), isFalse);
  });

  test('the build is refused when a table is left empty', () async {
    final partial = demoSeeders()
        .where((s) => s.name != 'queries, rules, safety and views')
        .toList();

    await expectLater(
      build(seeders: partial),
      throwsA(isA<DemoBuildRefused>()),
    );
    expect(Directory(p.join(dir.path, 'out')).existsSync(), isFalse);
  });

  test('manifest entries merge, keeping older schemas for older apps', () {
    final merged = DemoBuilder.mergeManifest(
      existing:
          '{"formatVersion":1,"packages":[{"schemaVersion":300,"url":"https://e.com/a.zip","sha256":"${'a' * 64}","size":1,"generatedAt":"2026-01-01T00:00:00.000Z"},{"schemaVersion":318,"url":"https://e.com/old.zip","sha256":"${'b' * 64}","size":1,"generatedAt":"2026-01-01T00:00:00.000Z"}]}',
      entry:
          '{"schemaVersion":318,"url":"https://e.com/new.zip","sha256":"${'c' * 64}","size":2,"generatedAt":"2026-10-01T00:00:00.000Z"}',
    );

    expect(merged, contains('a.zip'));
    expect(merged, contains('new.zip'));
    expect(merged, isNot(contains('old.zip')));
  });
}

/// Writes the photos folder's absolute path into a dive's notes, as a seeder
/// that forgot to make a path relative would.
class _MachinePathSeeder implements DemoSeeder {
  @override
  String get name => 'machine path';

  @override
  Future<void> seed(DemoSeedContext ctx) => ctx.db.customStatement(
    'UPDATE dives SET notes = ? WHERE id = (SELECT id FROM dives LIMIT 1)',
    ['See ${ctx.photosDir}'],
  );
}
