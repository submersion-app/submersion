import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/demo_mode/data/demo_database_switcher.dart';
import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/data/demo_manifest_client.dart';
import 'package:submersion/features/demo_mode/data/demo_package_extractor.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';

/// Writes a database file at [path] holding one default diver.
Future<void> writeDatabaseWithDiver(String path, String diverId) async {
  await Directory(p.dirname(path)).create(recursive: true);
  final db = AppDatabase(
    NativeDatabase(File(path), setup: registerAppSqlFunctions),
  );
  await db.customStatement(
    'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
    "VALUES ('$diverId', '$diverId', 1, 0, 0)",
  );
  await db.close();
}

final testPackage = DemoPackage(
  schemaVersion: 318,
  url: Uri.parse('https://example.com/demo.zip'),
  sha256: 'a' * 64,
  size: 10,
  generatedAt: DateTime.utc(2026, 10, 20),
);

class FakeManifestClient implements DemoManifestClient {
  FakeManifestClient([this.package]);

  final DemoPackage? package;

  @override
  Duration get timeout => Duration.zero;

  @override
  Future<DemoPackage?> fetchBest(int appSchemaVersion) async => package;
}

class FakeDownloader implements DemoDownloader {
  FakeDownloader({this.failWith});

  final DemoDownloadFailure? failWith;

  @override
  Duration get connectTimeout => Duration.zero;

  @override
  Duration get idleTimeout => Duration.zero;

  @override
  Future<File> download(
    DemoPackage pkg,
    File dest, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (failWith != null) throw DemoDownloadException(failWith!);
    await dest.parent.create(recursive: true);
    await dest.writeAsString('zip');
    onProgress?.call(pkg.size, pkg.size);
    return dest;
  }
}

/// Writes a demo database with diver `demo-diver` and one photo, as a real
/// package would unpack.
class FakeExtractor implements DemoPackageExtractor {
  @override
  int get maxExtractedBytes => 0;

  @override
  Future<void> extract(File zip, DemoPaths paths) async {
    await writeDatabaseWithDiver(paths.databaseFile, 'demo-diver');
    await Directory(paths.photosDir).create(recursive: true);
    await File(p.join(paths.photosDir, 'reef.jpg')).writeAsString('jpg');
  }
}

/// Opens real files, recording the key each open was given.
class FakeSwitcher implements DemoDatabaseSwitcher {
  FakeSwitcher({this.failOpenOf});

  final String? failOpenOf;
  AppDatabase? _db;
  String? openPath;
  final keys = <String?>[];

  @override
  AppDatabase get current => _db!;

  @override
  Future<void> openAt(String path, {required String? keyHex}) async {
    if (path == failOpenOf) throw StateError('cannot open $path');
    await _db?.close();
    keys.add(keyHex);
    _db = AppDatabase(
      NativeDatabase(File(path), setup: registerAppSqlFunctions),
    );
    openPath = path;
  }

  Future<void> close() async => _db?.close();
}
