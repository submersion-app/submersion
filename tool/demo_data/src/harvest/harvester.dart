import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show DriftSqlType;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/parsers/placeholder_parser.dart';
import 'package:submersion/features/universal_import/data/services/divemate_schema.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/format_detector.dart';
import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';

import '../shape/dive_shape.dart';
import '../shape/shape_extractor.dart';

class HarvestResult {
  const HarvestResult({
    required this.shapes,
    required this.sourceStringHashes,
    required this.perSourceCounts,
    required this.skipped,
  });

  final List<DiveShape> shapes;

  /// Salted hashes of every text value in the sources, for the privacy
  /// check; never the text itself.
  final Set<String> sourceStringHashes;
  final Map<String, int> perSourceCounts;
  final List<String> skipped;
}

// The demo-data tools run under `flutter test` (see tool/demo_data/README.md)
// and drive the app's database the way its tests do.
// ignore_for_file: invalid_use_of_visible_for_testing_member

/// Reads real dive logs and keeps only their shapes (issue #3708).
///
/// Each dive file goes through the app's own parser and importer into a
/// scratch database; a Submersion database is read from a copy. Shapes come
/// out of that database, so every format yields the same anonymous model.
class Harvester {
  Harvester({required this.salt, required this.prefs});

  final String salt;
  final SharedPreferences prefs;

  /// Computer-generated logbooks: real data only.
  static const excludedNames = {
    'Synthetic dives 1000.uddf',
    'submersion_multitank_500dives.uddf',
  };

  static bool isExcluded(String path) =>
      excludedNames.contains(p.basename(path)) ||
      path.contains('scrubber-1500-dives');

  static String hashString(String salt, String value) => sha256
      .convert(utf8.encode('$salt\u0000${value.trim().toLowerCase()}'))
      .toString();

  final _shapes = <String, DiveShape>{};
  final _hashes = <String>{};
  final _counts = <String, int>{};
  final _skipped = <String>[];

  Future<HarvestResult> harvest(List<String> paths) async {
    for (final path in paths) {
      await _visit(path);
    }
    return HarvestResult(
      shapes: _shapes.values.toList(),
      sourceStringHashes: _hashes,
      perSourceCounts: _counts,
      skipped: _skipped,
    );
  }

  Future<void> _visit(String path) async {
    if (isExcluded(path)) {
      _skipped.add('$path: computer-generated, excluded');
      return;
    }
    if (await FileSystemEntity.isDirectory(path)) {
      final entries = Directory(path).listSync()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final e in entries) {
        if (p.basename(e.path).startsWith('.')) continue;
        await _visit(e.path);
      }
      return;
    }
    try {
      final bytes = await File(path).readAsBytes();
      if (path.toLowerCase().endsWith('.zip')) {
        await _visitZip(path, bytes);
      } else if (_isSubmersionDatabase(path, bytes)) {
        await _harvestSubmersion(path);
      } else {
        await _harvestFile(path, bytes);
      }
    } on Object catch (e) {
      _skipped.add('$path: $e');
    }
  }

  Future<void> _visitZip(String path, List<int> bytes) async {
    final tmp = Directory.systemTemp.createTempSync('harvest_zip');
    try {
      for (final f in ZipDecoder().decodeBytes(bytes).files) {
        if (!f.isFile || f.name.contains('..') || f.name.startsWith('/')) {
          continue;
        }
        final out = File(p.join(tmp.path, f.name));
        await out.parent.create(recursive: true);
        await out.writeAsBytes(f.content);
      }
      await _visit(tmp.path);
    } finally {
      tmp.deleteSync(recursive: true);
    }
  }

  static const _sqliteMagic = 'SQLite format 3';

  static bool _isSqlite(List<int> bytes) =>
      bytes.length >= 16 &&
      String.fromCharCodes(bytes.sublist(0, 15)) == _sqliteMagic;

  bool _isSubmersionDatabase(String path, List<int> bytes) {
    if (!_isSqlite(bytes)) return false;
    final tables = _tableNames(path);
    return tables.containsAll(const {'divers', 'dives', 'diver_settings'});
  }

  Set<String> _tableNames(String path) {
    final db = sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly);
    try {
      return {
        for (final row in db.select(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        ))
          row['name'] as String,
      };
    } finally {
      db.close();
    }
  }

  Future<void> _harvestSubmersion(String path) async {
    final tmp = Directory.systemTemp.createTempSync('harvest_db');
    try {
      final copy = p.join(tmp.path, 'source.db');
      File(path).copySync(copy);
      for (final side in ['-wal', '-shm']) {
        if (File('$path$side').existsSync()) {
          File('$path$side').copySync('$copy$side');
        }
      }
      final db = AppDatabase(
        NativeDatabase(File(copy), setup: registerAppSqlFunctions),
      );
      await _harvestDatabase(p.basename(path), db);
    } finally {
      tmp.deleteSync(recursive: true);
    }
  }

  Future<void> _harvestFile(String path, List<int> bytes) async {
    final data = Uint8List.fromList(bytes);
    final format = await _detect(data);
    final parser = parserForFormat(format);
    if (parser is PlaceholderParser || format == ImportFormat.unknown) {
      _skipped.add('$path: not a dive log the app can import');
      return;
    }
    final payload = await parser.parse(data);
    final dives = UniversalAdapter.payloadToUddfResult(payload);
    if (dives.dives.isEmpty) {
      _skipped.add('$path: no dives');
      return;
    }
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    DatabaseService.instance.setTestDatabase(db);
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('harvest', 'harvest', 0, 0)",
    );
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    try {
      await UddfEntityImporter().import(
        data: dives,
        selections: UddfImportSelections(
          dives: {for (var i = 0; i < dives.dives.length; i++) i},
        ),
        repositories: universalImportRepositories(container),
        diverId: 'harvest',
      );
    } finally {
      container.dispose();
    }
    await _harvestDatabase(p.basename(path), db);
  }

  /// The app's own detection, including the SQLite flavours the import
  /// screen resolves by probing the table names.
  static Future<ImportFormat> _detect(Uint8List data) async {
    final ImportFormat format;
    try {
      format = const FormatDetector().detect(data).format;
    } on FormatException {
      return ImportFormat.unknown;
    }
    if (format != ImportFormat.sqlite) return format;
    final tables = await ShearwaterDbReader.probeSqliteTableNames(data);
    if (ShearwaterDbReader.matchesTables(tables)) {
      return ImportFormat.shearwaterDb;
    }
    if (MacDiveDbReader.matchesTables(tables)) {
      return ImportFormat.macdiveSqlite;
    }
    if (DivingLogDbReader.matchesTables(tables)) {
      return await DiveMateSchema.isDiveMateDb(data)
          ? ImportFormat.diveMateDdb
          : ImportFormat.divingLogSqlite;
    }
    return ImportFormat.unknown;
  }

  Future<void> _harvestDatabase(String source, AppDatabase db) async {
    DatabaseService.instance.setTestDatabase(db);
    try {
      var added = 0;
      for (final shape in await ShapeExtractor().fromDatabase()) {
        if (_shapes.putIfAbsent(shape.id, () => shape) == shape) added++;
      }
      _counts[source] = (_counts[source] ?? 0) + added;
      await _collectStrings(db);
    } finally {
      await db.close();
      DatabaseService.instance.resetForTesting();
    }
  }

  Future<void> _collectStrings(AppDatabase db) async {
    for (final t in db.allTables) {
      for (final c in t.$columns) {
        if (c.type != DriftSqlType.string) continue;
        final rows = await db
            .customSelect(
              'SELECT DISTINCT "${c.name}" AS v FROM "${t.actualTableName}" '
              'WHERE "${c.name}" IS NOT NULL',
            )
            .get();
        for (final row in rows) {
          final v = row.read<String>('v').trim();
          if (v.length >= 3) _hashes.add(hashString(salt, v));
        }
      }
    }
  }
}

/// Writes a harvest to a directory outside the repository.
class HarvestWriter {
  static Future<void> write(
    HarvestResult result, {
    required String outDir,
    required String salt,
    required String repoRoot,
  }) async {
    final out = p.normalize(p.absolute(outDir));
    final repo = p.normalize(p.absolute(repoRoot));
    if (out == repo || p.isWithin(repo, out) || _inGitCheckout(out)) {
      throw ArgumentError.value(
        outDir,
        'outDir',
        'must be outside the repository: harvested data is never committed',
      );
    }
    await Directory(out).create(recursive: true);
    final lines = [for (final s in result.shapes) jsonEncode(s.toJson())];
    await File(
      p.join(out, 'shapes.jsonl.gz'),
    ).writeAsBytes(gzip.encode(utf8.encode('${lines.join('\n')}\n')));
    final hashes = result.sourceStringHashes.toList()..sort();
    await File(
      p.join(out, 'source_strings.txt'),
    ).writeAsString('${hashes.join('\n')}\n');
    await File(p.join(out, 'salt.txt')).writeAsString('$salt\n');
  }

  /// Whether [dir], or the nearest folder above it that exists (followed
  /// through symlinks), sits in any git checkout: another checkout of this
  /// repository is as easy to commit from as this one.
  static bool _inGitCheckout(String dir) {
    var probe = dir;
    while (!Directory(probe).existsSync() && p.dirname(probe) != probe) {
      probe = p.dirname(probe);
    }
    var current = Directory(probe).resolveSymbolicLinksSync();
    while (true) {
      if (FileSystemEntity.typeSync(p.join(current, '.git')) !=
          FileSystemEntityType.notFound) {
        return true;
      }
      final parent = p.dirname(current);
      if (parent == current) return false;
      current = parent;
    }
  }

  static Future<List<DiveShape>> readShapes(String dir) async {
    final text = utf8.decode(
      gzip.decode(await File(p.join(dir, 'shapes.jsonl.gz')).readAsBytes()),
    );
    return [
      for (final line in const LineSplitter().convert(text))
        if (line.trim().isNotEmpty)
          DiveShape.fromJson((jsonDecode(line) as Map).cast<String, Object?>()),
    ];
  }
}
