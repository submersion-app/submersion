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

  // A photo of something no dive meets: it never reaches the package.
  const stray = DemoPhoto(
    fileName: 'stray.jpg',
    credit: 'Test Author, CC0',
    subject: 'A fish that lives nowhere',
  );
  final photos = [...testPhotos, stray];

  // For a test that seeds a whole 700-dive logbook of its own, which a shared
  // CI runner can take past the usual two minutes for.
  const wholeBuild = Timeout(Duration(minutes: 6));

  void writePhotos(Directory root) {
    for (final photo in photos) {
      File(p.join(root.path, 'photos', photo.fileName))
        ..createSync(recursive: true)
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    }
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('demo_build');
    writePhotos(dir);
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
    dir.deleteSync(recursive: true);
  });

  Future<DemoBuildOutput> build({
    Directory? root,
    List<Object>? seeders,
    Set<String> refusedNames = const {},
  }) {
    final folder = (root ?? dir).path;
    return DemoBuilder().build(
      shapes: syntheticShapes(),
      photosDir: p.join(folder, 'photos'),
      photos: photos,
      seed: 7,
      anchor: DateTime(2026, 10, 1),
      outDir: p.join(folder, 'out'),
      seeders: seeders?.cast(),
      refusedNames: refusedNames,
    );
  }

  // One whole logbook, for the tests that only read what a build produced.
  // setUpAll has twelve minutes, where a test has two.
  group('from one build', () {
    late Directory builtDir;
    late DemoBuildOutput built;

    setUpAll(() async {
      builtDir = Directory.systemTemp.createTempSync('demo_built');
      writePhotos(builtDir);
      built = await build(root: builtDir);
    });

    tearDownAll(() {
      DatabaseService.instance.resetForTesting();
      builtDir.deleteSync(recursive: true);
    });

    test(
      'a synthetic build produces a zip whose manifest entry matches it',
      () {
        final bytes = built.zip.readAsBytesSync();
        expect(built.package.sha256, sha256.convert(bytes).toString());
        expect(built.package.size, bytes.length);
        expect(built.package.schemaVersion, AppDatabase.currentSchemaVersion);
        expect(
          built.package.url.toString(),
          endsWith(p.basename(built.zip.path)),
        );
        final names = ZipDecoder()
            .decodeBytes(bytes)
            .files
            .map((f) => f.name)
            .toSet();
        expect(names, contains('submersion_demo.db'));
        expect(
          names,
          containsAll(testPhotos.map((f) => 'photos/${f.fileName}')),
        );
        expect(names, isNot(contains('photos/${stray.fileName}')));
        expect(
          File(
            p.join(builtDir.path, 'out', 'manifest-entry.json'),
          ).existsSync(),
          isTrue,
        );
      },
    );

    test('no value in the published database names a build folder', () async {
      final db = _publishedDatabase(built, dir);
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
      final db = _publishedDatabase(built, dir);
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

    test('a refused name never reaches the logbook', () async {
      final names = await _buddyNames(built, dir);
      final refused = names.firstWhere((n) => n != 'Mara Lindqvist');

      final again = await build(refusedNames: {refused});

      expect(await _buddyNames(again, dir), isNot(contains(refused)));
    }, timeout: wholeBuild);
  });

  test('the build writes without syncing each commit to disk', () async {
    final probe = _CommitProbe();

    await expectLater(
      build(seeders: [probe]),
      throwsA(isA<DemoBuildRefused>()),
    );

    // Issue #3814: why these two are set is in the builder.
    expect(probe.synchronous, 0);
    expect(probe.journalMode, 'memory');
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
  }, timeout: wholeBuild);

  test('the build is refused when a table is left empty', () async {
    await expectLater(
      build(seeders: const []),
      throwsA(
        isA<DemoBuildRefused>().having(
          (e) => '$e',
          'message',
          contains('empty tables'),
        ),
      ),
    );
    expect(Directory(p.join(dir.path, 'out')).existsSync(), isFalse);
  });

  test('the builder refuses a plan the shapes cannot cover', () async {
    // Four rebreather shapes cover at most twelve rebreather dives; the story
    // has 15 to 18.
    var rebreather = 0;
    final noRebreather = [
      for (final s in syntheticShapes())
        if (s.diveMode != 'ccr' || rebreather++ < 4) s,
    ];

    await expectLater(
      DemoBuilder().build(
        shapes: noRebreather,
        photosDir: p.join(dir.path, 'photos'),
        photos: testPhotos,
        seed: 7,
        anchor: DateTime(2026, 10, 1),
        outDir: p.join(dir.path, 'out'),
      ),
      throwsA(
        isA<DemoBuildRefused>().having(
          (e) => e.toString(),
          'message',
          contains('ccr'),
        ),
      ),
    );
    expect(Directory(p.join(dir.path, 'out')).existsSync(), isFalse);
  });

  test('the limits are 12 MB for the database and 28 MB for the package', () {
    expect(DemoBuilder.maxDatabaseZipBytes, 12 * 1024 * 1024);
    expect(DemoBuilder.maxPackageBytes, 28 * 1024 * 1024);
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

/// Reads how the build's connection commits. The tables stay empty, so the
/// build is refused without seeding a logbook.
class _CommitProbe implements DemoSeeder {
  int? synchronous;
  String? journalMode;

  @override
  String get name => 'commit probe';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final sync = await ctx.db.customSelect('PRAGMA synchronous').getSingle();
    synchronous = sync.read<int>('synchronous');
    final journal = await ctx.db
        .customSelect('PRAGMA journal_mode')
        .getSingle();
    journalMode = journal.read<String>('journal_mode');
  }
}

/// The database as a built package's zip carries it, opened from a copy in
/// [folder].
AppDatabase _publishedDatabase(DemoBuildOutput out, Directory folder) {
  final entry = ZipDecoder()
      .decodeBytes(out.zip.readAsBytesSync())
      .files
      .firstWhere((f) => f.name == 'submersion_demo.db');
  final copy = File(p.join(folder.path, 'published.db'))
    ..writeAsBytesSync(entry.content);
  return AppDatabase(NativeDatabase(copy, setup: registerAppSqlFunctions));
}

/// The buddies' names in a built package's database.
Future<List<String>> _buddyNames(DemoBuildOutput out, Directory folder) async {
  final db = _publishedDatabase(out, folder);
  try {
    final rows = await db.customSelect('SELECT name FROM buddies').get();
    return [for (final r in rows) r.read<String>('name')];
  } finally {
    await db.close();
  }
}
