import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../tool/demo_data/src/harvest/harvester.dart';
import 'shape_extractor_test.dart' show decoDive;

const _ratioFixture =
    'test/fixtures/universal_import/ratio_xml/'
    'IX3M_2_PRO_123456-dive_14-19880731_190154.xml';

void main() {
  late Directory dir;
  late SharedPreferences prefs;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('harvest');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
    dir.deleteSync(recursive: true);
  });

  Harvester harvester() => Harvester(salt: 'pepper', prefs: prefs);

  /// A Submersion database holding the deco dive, with a diver whose name is
  /// the kind of thing that must never leave the harvest.
  Future<String> submersionDatabase(String name) async {
    final path = p.join(dir.path, name);
    final db = AppDatabase(
      NativeDatabase(File(path), setup: registerAppSqlFunctions),
    );
    DatabaseService.instance.setTestDatabase(db);
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('d1', 'Jane Diver', 0, 0)",
    );
    await DiveRepository().createDive(decoDive());
    await db.close();
    DatabaseService.instance.resetForTesting();
    return path;
  }

  test('excluded generated files are skipped and reported', () async {
    for (final name in [
      'Synthetic dives 1000.uddf',
      'submersion_multitank_500dives.uddf',
    ]) {
      File(p.join(dir.path, name)).writeAsStringSync('<uddf/>');
    }
    Directory(p.join(dir.path, 'scrubber-1500-dives')).createSync();
    File(
      p.join(dir.path, 'scrubber-1500-dives', 'a.uddf'),
    ).writeAsStringSync('<uddf/>');

    final result = await harvester().harvest([dir.path]);

    expect(result.shapes, isEmpty);
    expect(
      result.skipped.where((s) => s.contains('computer-generated')),
      hasLength(3),
    );
  });

  test('a binary file that is not a dive log is skipped cleanly', () async {
    final jpeg = p.join(dir.path, 'photo.jpg');
    File(
      jpeg,
    ).writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(64, 0)]);

    final result = await harvester().harvest([jpeg]);

    expect(result.skipped.single, contains('not a dive log'));
  });

  test('a dive file is imported through the app and shaped', () async {
    final result = await harvester().harvest([_ratioFixture]);

    expect(result.shapes, hasLength(1));
    expect(result.shapes.single.samples.length, greaterThan(200));
  });

  test('the same dive in two sources yields one shape', () async {
    final copy = p.join(dir.path, 'copy.xml');
    File(_ratioFixture).copySync(copy);

    final result = await harvester().harvest([_ratioFixture, copy]);

    expect(result.shapes, hasLength(1));
  });

  test('a Submersion database is read without being changed', () async {
    final path = await submersionDatabase('logbook.db');
    final before = File(path).readAsBytesSync();

    final result = await harvester().harvest([path]);

    expect(result.shapes, hasLength(1));
    expect(File(path).readAsBytesSync(), before);
  });

  test('source strings are kept only as salted hashes', () async {
    final path = await submersionDatabase('logbook.db');

    final result = await harvester().harvest([path]);

    final jane = sha256
        .convert(utf8.encode('pepper\u0000jane diver'))
        .toString();
    expect(result.sourceStringHashes, contains(jane));
    expect(Harvester.hashString('pepper', '  Jane Diver '), jane);
    expect(
      result.sourceStringHashes.every(
        (h) => RegExp(r'^[0-9a-f]{64}$').hasMatch(h),
      ),
      isTrue,
    );
  });

  test('an output directory inside the repository is refused', () async {
    final result = await harvester().harvest(const []);
    final repo = Directory.current.path;

    expect(
      () => HarvestWriter.write(
        result,
        outDir: p.join(repo, 'shapes'),
        salt: 'pepper',
        repoRoot: repo,
      ),
      throwsArgumentError,
    );
  });

  test('an output directory in any other git checkout is refused', () async {
    // Another checkout of the repository (the main one, when the harvest
    // runs from a worktree) is just as easy to commit from.
    final result = await harvester().harvest(const []);
    final checkout = Directory(p.join(dir.path, 'checkout'))..createSync();
    File(p.join(checkout.path, '.git')).writeAsStringSync('gitdir: x');

    expect(
      () => HarvestWriter.write(
        result,
        outDir: p.join(checkout.path, 'harvest'),
        salt: 'pepper',
        repoRoot: p.join(dir.path, 'not-here'),
      ),
      throwsArgumentError,
    );
  });

  test(
    'the writer stores shapes, hashes and salt, and no source text',
    () async {
      final path = await submersionDatabase('logbook.db');
      final result = await harvester().harvest([path]);
      final out = p.join(dir.path, 'out');

      await HarvestWriter.write(
        result,
        outDir: out,
        salt: 'pepper',
        repoRoot: p.join(dir.path, 'not-here'),
      );

      final shapes = utf8.decode(
        gzip.decode(File(p.join(out, 'shapes.jsonl.gz')).readAsBytesSync()),
      );
      expect(shapes.trim().split('\n'), hasLength(1));
      expect(shapes, isNot(contains('Jane')));
      expect(
        File(p.join(out, 'source_strings.txt')).readAsStringSync(),
        isNot(contains('Jane')),
      );
      expect(File(p.join(out, 'salt.txt')).readAsStringSync().trim(), 'pepper');
    },
  );
}
