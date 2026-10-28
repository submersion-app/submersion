// The demo-data tools run under `flutter test` and drive the app's database
// the way its tests do.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';

import '../checks/coverage_check.dart';
import '../checks/machine_path_check.dart';
import '../checks/privacy_check.dart';
import '../checks/public_vocabulary.dart';
import '../seeders/demo_seeding.dart';
import '../seeders/seed_context.dart';
import '../shape/dive_shape.dart';
import '../shape/shape_budget.dart';
import '../shape/shape_library.dart';
import '../story/catalog.dart';
import '../story/story_planner.dart';

class DemoBuildRefused implements Exception {
  const DemoBuildRefused(this.reason);

  final String reason;

  @override
  String toString() => 'DemoBuildRefused: $reason';
}

class DemoBuildOutput {
  const DemoBuildOutput({required this.zip, required this.package});

  final File zip;
  final DemoPackage package;
}

/// Builds the demo logbook (issue #3708): plans the story, seeds every part
/// of the app, refuses a logbook that leaves a table empty or resembles a
/// real dive, and packages the database with its photos for the `demo-data`
/// release.
class DemoBuilder {
  static const maxDatabaseZipBytes = 12 * 1024 * 1024;
  static const maxPackageBytes = 28 * 1024 * 1024;
  static const releaseBase =
      'https://github.com/submersion-app/submersion/releases/download/demo-data';

  Future<DemoBuildOutput> build({
    required List<DiveShape> shapes,
    required String photosDir,
    required List<DemoPhoto> photos,
    required int seed,
    required DateTime anchor,
    required String outDir,
    String catalogDir = 'assets/data',
    Set<String>? sourceStringHashes,
    String? salt,
    List<DemoSeeder>? seeders,
    Set<String> refusedNames = const {},
  }) async {
    final work = Directory.systemTemp.createTempSync('demo_pack');
    try {
      final dbPath = p.join(work.path, 'submersion_demo.db');
      final db = AppDatabase(
        NativeDatabase(File(dbPath), setup: registerAppSqlFunctions),
      );
      DatabaseService.instance.setTestDatabase(db);
      final catalog = Catalog.load(catalogDir);
      final plan = StoryPlanner(
        Random(seed),
        catalog,
        refusedNames: refusedNames,
      ).plan(anchor: anchor);
      final library = ShapeLibrary(shapes, Random(seed));
      final short = shapeShortfalls(plan, library.shapes);
      if (short.isNotEmpty) {
        await db.close();
        DatabaseService.instance.resetForTesting();
        throw DemoBuildRefused('not enough dive shapes: ${short.join('; ')}');
      }
      final ctx = DemoSeedContext(
        db: db,
        plan: plan,
        library: library,
        random: Random(seed),
        photosDir: photosDir,
        photoFiles: photos,
      );
      try {
        for (final seeder in seeders ?? demoSeeders()) {
          await seeder.seed(ctx);
        }
        final empty = await CoverageCheck.emptyTables(db);
        if (empty.isNotEmpty) {
          throw DemoBuildRefused('empty tables: ${empty.join(', ')}');
        }
        final machinePaths = await MachinePathCheck.run(db, [
          photosDir,
          outDir,
          work.path,
        ]);
        if (machinePaths.isNotEmpty) {
          throw DemoBuildRefused(
            'values name a folder on this machine: ${machinePaths.join(', ')}',
          );
        }
        if (sourceStringHashes != null && salt != null) {
          final violations = await PrivacyCheck.run(
            demoDb: db,
            sources: shapes,
            sourceStringHashes: sourceStringHashes,
            salt: salt,
            publicStrings: {
              ...catalog.publicStrings,
              ...demoPublicVocabulary,
              ...await appSeededStrings(),
            },
          );
          if (violations.isNotEmpty) {
            throw DemoBuildRefused(
              'privacy check failed (${violations.length}): '
              '${violations.take(40).join('; ')}',
            );
          }
        }
        await db.customStatement('VACUUM');
      } finally {
        await db.close();
        DatabaseService.instance.resetForTesting();
      }

      final dbBytes = File(dbPath).readAsBytesSync();
      final dbOnly = ZipEncoder().encodeBytes(
        Archive()..addFile(ArchiveFile.bytes('submersion_demo.db', dbBytes)),
      );
      if (dbOnly.length > maxDatabaseZipBytes) {
        throw DemoBuildRefused(
          'database is ${dbOnly.length} bytes compressed; the limit is '
          '$maxDatabaseZipBytes',
        );
      }
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('submersion_demo.db', dbBytes));
      for (final photo in photos) {
        if (!ctx.linkedPhotos.contains(photo.fileName)) continue;
        archive.addFile(
          ArchiveFile.bytes(
            'photos/${photo.fileName}',
            File(p.join(photosDir, photo.fileName)).readAsBytesSync(),
          ),
        );
      }
      final zipBytes = ZipEncoder().encodeBytes(archive);
      if (zipBytes.length > maxPackageBytes) {
        throw DemoBuildRefused(
          'package is ${zipBytes.length} bytes; the limit is $maxPackageBytes',
        );
      }

      await Directory(outDir).create(recursive: true);
      const schema = AppDatabase.currentSchemaVersion;
      const name = 'submersion-demo-s$schema.zip';
      final zip = File(p.join(outDir, name))..writeAsBytesSync(zipBytes);
      final package = DemoPackage(
        schemaVersion: schema,
        url: Uri.parse('$releaseBase/$name'),
        sha256: sha256.convert(zipBytes).toString(),
        size: zipBytes.length,
        generatedAt: DateTime.now().toUtc(),
      );
      File(
        p.join(outDir, 'manifest-entry.json'),
      ).writeAsStringSync(jsonEncode(package.toJson()));
      return DemoBuildOutput(zip: zip, package: package);
    } finally {
      work.deleteSync(recursive: true);
    }
  }

  /// [existing] manifest JSON (or null for none) with [entry] added, replacing
  /// any package built at the same schema. Packages for older schemas stay,
  /// so older apps keep a file they can open.
  static String mergeManifest({String? existing, required String entry}) {
    final current = existing == null
        ? const <DemoPackage>[]
        : DemoManifest.tryParse(existing)?.packages ?? const <DemoPackage>[];
    final added = DemoPackage.fromJson(
      (jsonDecode(entry) as Map).cast<String, Object?>(),
    );
    final packages = [
      for (final pkg in current)
        if (pkg.schemaVersion != added.schemaVersion) pkg,
      added,
    ]..sort((a, b) => a.schemaVersion.compareTo(b.schemaVersion));
    return const JsonEncoder.withIndent('  ').convert({
      'formatVersion': DemoManifest.currentFormatVersion,
      'packages': [for (final pkg in packages) pkg.toJson()],
    });
  }
}
